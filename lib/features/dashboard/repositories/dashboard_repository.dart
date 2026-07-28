import '../../../core/network/api_client.dart';
import '../../../models/dashboard/dashboard_data.dart';
import '../../../models/dashboard/dashboard_widget_config.dart';

class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> _safeList(String path, String gaToken) async {
    try {
      final response = await _apiClient.get(path, gaToken: gaToken, cache: true);
      final body = response.body;
      if (body is List) return body.whereType<Map<String, dynamic>>().toList();
      if (body is Map<String, dynamic> && body['data'] is List) {
        return (body['data'] as List).whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<DashboardData> fetchData({required String gaToken}) async {
    final results = await Future.wait([
      _safeList('/api/agents', gaToken),
      _safeList('/api/connections', gaToken),
      _safeList('/api/knowledge', gaToken),
      _safeList('/api/workflows', gaToken),
      _safeList('/api/skills', gaToken),
      _safeList('/api/memory', gaToken),
      _safeList('/api/connections/tokens-daily?days=30', gaToken),
    ]);

    return DashboardData(
      agents: results[0],
      connections: results[1],
      knowledge: results[2],
      workflows: results[3],
      skills: results[4],
      memory: results[5],
      tokenDaily: results[6].map(TokenDailyPoint.fromJson).toList(),
    );
  }

  Future<List<ConnectionTestResult>> testAllConnections(String gaToken, {List<String>? ids}) async {
    final response = await _apiClient.post(
      '/api/connections/test-all',
      gaToken: gaToken,
      body: {'ids': ?ids},
    );
    final body = response.body;
    if (body is! List) return const [];
    return body.whereType<Map<String, dynamic>>().map(ConnectionTestResult.fromJson).toList();
  }

  Future<List<String>?> getLayout(String gaToken) async {
    try {
      final response = await _apiClient.get('/api/settings/dashboard-layout', gaToken: gaToken);
      final layout = response.json['layout'];
      if (layout is! List) return null;
      final valid = layout
          .map((e) => e.toString())
          .where((id) => kDashboardWidgetIds.contains(id))
          .toSet()
          .toList();
      return valid.isEmpty ? null : valid;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLayout(String gaToken, List<String> layout) async {
    await _apiClient.put('/api/settings/dashboard-layout', gaToken: gaToken, body: {'layout': layout});
  }

  Future<Map<String, DashboardWidgetConfig>> getConfig(String gaToken) async {
    try {
      final response = await _apiClient.get('/api/settings/dashboard-config', gaToken: gaToken);
      final config = response.json['config'];
      if (config is! Map<String, dynamic>) return {};
      return config.map(
        (key, value) => MapEntry(key, DashboardWidgetConfig.fromJson(value as Map<String, dynamic>? ?? {})),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveConfig(String gaToken, Map<String, DashboardWidgetConfig> config) async {
    await _apiClient.put(
      '/api/settings/dashboard-config',
      gaToken: gaToken,
      body: {'config': config.map((key, value) => MapEntry(key, value.toJson()))},
    );
  }

  Future<List<Map<String, dynamic>>> fetchFeed(String gaToken, {List<String>? types, int limit = 8}) async {
    final single = (types != null && types.length == 1) ? types.first : null;
    final multiplier = single != null ? 1 : (types?.length ?? 1).clamp(1, 3);
    final fetchLimit = (limit * multiplier).clamp(1, 100);
    final path = Uri(
      path: '/api/feed',
      queryParameters: {'limit': '$fetchLimit', 'type': ?single},
    ).toString();
    try {
      final response = await _apiClient.get(path, gaToken: gaToken, cache: true);
      final body = response.body;
      if (body is! List) return const [];
      return body.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return const [];
    }
  }
}
