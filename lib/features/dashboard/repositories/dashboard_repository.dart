import '../../../core/network/api_client.dart';
import '../../../core/network/page_result.dart';
import '../../../models/dashboard/dashboard_data.dart';
import '../../../models/dashboard/dashboard_feed_item.dart';
import '../../../models/dashboard/dashboard_widget_config.dart';
import '../../../models/dashboard/dashboard_widget_instance.dart';
import '../../../models/dashboard/dashboard_widget_registry.dart';
import '../../../models/dashboard/notification_banner.dart';

class DashboardPreferences {
  const DashboardPreferences({
    required this.instances,
    required this.isVersioned,
  });

  final List<DashboardWidgetInstance> instances;
  final bool isVersioned;
}

class _LoadedSource {
  _LoadedSource(this.items, {int? total}) : total = total ?? items.length;

  final List<Map<String, dynamic>> items;
  final int total;
}

class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  static const _cursorSources = {
    DashboardDataSource.agents,
    DashboardDataSource.connections,
    DashboardDataSource.knowledge,
    DashboardDataSource.skills,
    DashboardDataSource.tools,
  };

  Future<_LoadedSource> _safeList(String path, String gaToken) async {
    try {
      final response = await _apiClient.get(
        path,
        gaToken: gaToken,
        cache: true,
      );
      final body = response.body;
      if (body is List) {
        return _LoadedSource(body.whereType<Map<String, dynamic>>().toList());
      }
      if (body is Map<String, dynamic> && body['data'] is List) {
        return _LoadedSource(
          (body['data'] as List).whereType<Map<String, dynamic>>().toList(),
        );
      }
      return _LoadedSource(const []);
    } catch (_) {
      return _LoadedSource(const []);
    }
  }

  Future<_LoadedSource> _safeCursorSummary(String path, String gaToken) async {
    try {
      final uri = Uri.parse(path);
      final response = await _apiClient.get(
        uri
            .replace(
              queryParameters: {
                ...uri.queryParameters,
                'limit': '100',
                'include_total': 'true',
              },
            )
            .toString(),
        gaToken: gaToken,
        cache: true,
      );
      final page = PageResult.fromCursorV2Response(response, (item) => item);
      return _LoadedSource(page.items, total: page.total);
    } catch (_) {
      return _LoadedSource(const []);
    }
  }

  /// Banners de notificación vigentes ahora, con el mensaje ya resuelto en
  /// el idioma del usuario — lista vacía si falla, es un aviso informativo,
  /// no debe romper el resto del dashboard.
  Future<List<NotificationBanner>> getActiveBanners(String gaToken) async {
    final source = await _safeList(
      '/api/settings/notification-banners/active',
      gaToken,
    );
    return source.items.map(NotificationBanner.fromJson).toList();
  }

  Future<DashboardData> fetchData({
    required String gaToken,
    required Set<DashboardDataSource> sources,
  }) async {
    final results = await Future.wait([
      _loadSource(
        sources,
        DashboardDataSource.agents,
        '/api/v2/agents',
        gaToken,
      ),
      _loadSource(
        sources,
        DashboardDataSource.connections,
        '/api/v2/connections',
        gaToken,
      ),
      _loadSource(
        sources,
        DashboardDataSource.knowledge,
        '/api/v2/knowledge',
        gaToken,
      ),
      _loadSource(
        sources,
        DashboardDataSource.workflows,
        '/api/workflows',
        gaToken,
      ),
      _loadSource(
        sources,
        DashboardDataSource.skills,
        '/api/v2/skills',
        gaToken,
      ),
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
      _loadSource(sources, DashboardDataSource.tools, '/api/v2/tools', gaToken),
    ]);

    return DashboardData(
      agents: results[0].items,
      agentTotalOverride: results[0].total,
      connections: results[1].items,
      knowledge: results[2].items,
      workflows: results[3].items,
      skills: results[4].items,
      skillTotalOverride: results[4].total,
      memory: results[5].items,
      tokenDaily: results[6].items.map(TokenDailyPoint.fromJson).toList(),
      groups: results[7].items,
      invitations: results[8].items,
      conversations: results[9].items,
      tools: results[10].items,
      toolTotalOverride: results[10].total,
    );
  }

  Future<_LoadedSource> _loadSource(
    Set<DashboardDataSource> sources,
    DashboardDataSource source,
    String path,
    String gaToken,
  ) {
    if (!sources.contains(source)) {
      return Future.value(_LoadedSource(const []));
    }
    return _cursorSources.contains(source)
        ? _safeCursorSummary(path, gaToken)
        : _safeList(path, gaToken);
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

  Future<List<DashboardFeedItem>> fetchFeed(
    String gaToken, {
    List<String>? types,
    int limit = 8,
  }) async {
    final single = (types != null && types.length == 1) ? types.first : null;
    final multiplier = single != null ? 1 : (types?.length ?? 1).clamp(1, 3);
    final fetchLimit = (limit * multiplier).clamp(1, 100);
    final path = Uri(
      path: '/api/v2/feed',
      queryParameters: {'limit': '$fetchLimit', 'type': ?single},
    ).toString();
    final response = await _apiClient.get(path, gaToken: gaToken, cache: true);
    final page = PageResult.fromCursorV2Response(
      response,
      DashboardFeedItem.fromJson,
    );
    return page.items;
  }
}
