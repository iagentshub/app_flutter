import '../../../core/network/api_client.dart';
import '../../../models/dashboard/dashboard_data.dart';
import '../../../models/dashboard/dashboard_widget_config.dart';
import '../../../models/dashboard/dashboard_widget_instance.dart';
import '../../../models/dashboard/dashboard_widget_registry.dart';

class DashboardPreferences {
  const DashboardPreferences({
    required this.instances,
    required this.isVersioned,
  });

  final List<DashboardWidgetInstance> instances;
  final bool isVersioned;
}

class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> _safeList(
    String path,
    String gaToken,
  ) async {
    try {
      final response = await _apiClient.get(
        path,
        gaToken: gaToken,
        cache: true,
      );
      final body = response.body;
      if (body is List) return body.whereType<Map<String, dynamic>>().toList();
      if (body is Map<String, dynamic> && body['data'] is List) {
        return (body['data'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<DashboardData> fetchData({
    required String gaToken,
    required Set<DashboardDataSource> sources,
  }) async {
    final results = await Future.wait([
      _loadSource(sources, DashboardDataSource.agents, '/api/agents', gaToken),
      _loadSource(
        sources,
        DashboardDataSource.connections,
        '/api/connections',
        gaToken,
      ),
      _loadSource(
        sources,
        DashboardDataSource.knowledge,
        '/api/knowledge',
        gaToken,
      ),
      _loadSource(
        sources,
        DashboardDataSource.workflows,
        '/api/workflows',
        gaToken,
      ),
      _loadSource(sources, DashboardDataSource.skills, '/api/skills', gaToken),
      _loadSource(sources, DashboardDataSource.memory, '/api/memory', gaToken),
      _loadSource(
        sources,
        DashboardDataSource.tokenDaily,
        '/api/connections/tokens-daily?days=90',
        gaToken,
      ),
      _loadSource(sources, DashboardDataSource.groups, '/api/groups', gaToken),
      _loadSource(
        sources,
        DashboardDataSource.invitations,
        '/api/groups/my-invitations',
        gaToken,
      ),
      _loadSource(
        sources,
        DashboardDataSource.conversations,
        '/api/chats/recent?limit=8',
        gaToken,
      ),
    ]);

    return DashboardData(
      agents: results[0],
      connections: results[1],
      knowledge: results[2],
      workflows: results[3],
      skills: results[4],
      memory: results[5],
      tokenDaily: results[6].map(TokenDailyPoint.fromJson).toList(),
      groups: results[7],
      invitations: results[8],
      conversations: results[9],
    );
  }

  Future<List<Map<String, dynamic>>> _loadSource(
    Set<DashboardDataSource> sources,
    DashboardDataSource source,
    String path,
    String gaToken,
  ) {
    if (!sources.contains(source)) return Future.value(const []);
    return _safeList(path, gaToken);
  }

  Future<List<ConnectionTestResult>> testAllConnections(
    String gaToken, {
    List<String>? ids,
  }) async {
    final response = await _apiClient.post(
      '/api/connections/test-all',
      gaToken: gaToken,
      body: {'ids': ?ids},
    );
    final body = response.body;
    if (body is! List) return const [];
    return body
        .whereType<Map<String, dynamic>>()
        .map(ConnectionTestResult.fromJson)
        .toList();
  }

  Future<DashboardPreferences> getPreferences(String gaToken) async {
    final results = await Future.wait([
      _getVersionedLayout(gaToken),
      _getLegacyLayout(gaToken),
      getConfig(gaToken),
    ]);
    final versioned = results[0] as List<DashboardWidgetInstance>?;
    if (versioned != null) {
      return DashboardPreferences(instances: versioned, isVersioned: true);
    }
    final legacy = results[1] as List<String>?;
    final config = results[2] as Map<String, DashboardWidgetConfig>;
    return DashboardPreferences(
      instances: legacy == null
          ? defaultDashboardInstances()
          : migrateLegacyDashboardLayout(legacy, config),
      isVersioned: false,
    );
  }

  Future<List<DashboardWidgetInstance>?> _getVersionedLayout(
    String gaToken,
  ) async {
    try {
      final response = await _apiClient.get(
        '/api/settings/dashboard-layout-v2',
        gaToken: gaToken,
        cache: true,
      );
      final items = response.json['items'];
      if (items is! List) return null;
      final seen = <String>{};
      return items
          .whereType<Map<String, dynamic>>()
          .map(DashboardWidgetInstance.fromJson)
          .where(
            (item) =>
                item.id.isNotEmpty &&
                seen.add(item.id) &&
                kDashboardWidgetIds.contains(item.type),
          )
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<String>?> _getLegacyLayout(String gaToken) async {
    try {
      final response = await _apiClient.get(
        '/api/settings/dashboard-layout',
        gaToken: gaToken,
        cache: true,
      );
      final layout = response.json['layout'];
      if (layout is! List) return null;
      final valid = layout
          .map(normalizeDashboardWidgetType)
          .where((id) => kDashboardWidgetIds.contains(id))
          .toSet()
          .toList();
      return valid;
    } catch (_) {
      return null;
    }
  }

  Future<void> savePreferences(
    String gaToken,
    List<DashboardWidgetInstance> instances,
  ) async {
    await _apiClient.put(
      '/api/settings/dashboard-layout-v2',
      gaToken: gaToken,
      body: {
        'version': 2,
        'items': instances.map((item) => item.toJson()).toList(),
      },
    );

    final legacyConfig = <String, DashboardWidgetConfig>{};
    for (final instance in instances) {
      legacyConfig.putIfAbsent(instance.type, () => instance.config);
    }
    await saveConfig(gaToken, legacyConfig);
  }

  Future<Map<String, DashboardWidgetConfig>> getConfig(String gaToken) async {
    try {
      final response = await _apiClient.get(
        '/api/settings/dashboard-config',
        gaToken: gaToken,
        cache: true,
      );
      final config = response.json['config'];
      if (config is! Map<String, dynamic>) return {};
      return config.map(
        (key, value) => MapEntry(
          normalizeDashboardWidgetType(key),
          DashboardWidgetConfig.fromJson(value as Map<String, dynamic>? ?? {}),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveConfig(
    String gaToken,
    Map<String, DashboardWidgetConfig> config,
  ) async {
    await _apiClient.put(
      '/api/settings/dashboard-config',
      gaToken: gaToken,
      body: {
        'config': config.map((key, value) => MapEntry(key, value.toJson())),
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchFeed(
    String gaToken, {
    List<String>? types,
    int limit = 8,
  }) async {
    final single = (types != null && types.length == 1) ? types.first : null;
    final multiplier = single != null ? 1 : (types?.length ?? 1).clamp(1, 3);
    final fetchLimit = (limit * multiplier).clamp(1, 100);
    final path = Uri(
      path: '/api/feed',
      queryParameters: {'limit': '$fetchLimit', 'type': ?single},
    ).toString();
    try {
      final response = await _apiClient.get(
        path,
        gaToken: gaToken,
        cache: true,
      );
      final body = response.body;
      if (body is! List) return const [];
      return body.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}
