import '../../../core/network/api_client.dart';
import '../../../models/dashboard/dashboard_data.dart';

class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> _safeList(String path, String gaToken) async {
    try {
      final response = await _apiClient.get(path, gaToken: gaToken);
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
}
