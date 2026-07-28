import '../../../core/network/api_client.dart';

class CentinelRepository {
  CentinelRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<Map<String, dynamic>> status(String token) async {
    final response = await apiClient.get('/api/admin/centinel/status', gaToken: token);
    return response.json;
  }

  Future<Map<String, dynamic>> run(
    String token, {
    String target = 'tests/',
    bool rerunFailed = false,
  }) async {
    final response = await apiClient.post(
      '/api/admin/centinel/run',
      gaToken: token,
      body: {
        'target': target,
        'rerun_failed': rerunFailed,
      },
    );
    return response.json;
  }

  Future<void> abort(String token) async {
    await apiClient.delete('/api/admin/centinel/run', gaToken: token);
  }

  Future<List<Map<String, dynamic>>> history(String token) async {
    final response = await apiClient.get('/api/admin/centinel/history', gaToken: token);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> tree(String token) async {
    final response = await apiClient.get('/api/admin/centinel/tree', gaToken: token);
    return response.json;
  }
}
