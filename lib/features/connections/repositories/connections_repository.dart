import '../../../core/network/api_client.dart';
import '../../../models/connections/connection_models.dart';

class ConnectionsRepository {
  ConnectionsRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<ConnectionItem>> listConnections(
    String token, {
    String? groupId,
  }) async {
    final query = groupId == null || groupId.isEmpty
        ? ''
        : '?group_id=${Uri.encodeComponent(groupId)}';
    final response = await apiClient.get(
      '/api/connections$query',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ConnectionItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getConnection(String token, String id) async {
    final response = await apiClient.get(
      '/api/connections/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return response.json;
  }

  Future<List<ConnectionProvider>> listProviders(String token) async {
    final response = await apiClient.get(
      '/api/connections/providers',
      gaToken: token,
      cache: true,
      ttl: const Duration(minutes: 10),
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ConnectionProvider.fromJson(item))
        .toList();
  }

  Future<Map<String, dynamic>> saveConnection(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/connections',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deleteConnection(String token, String id) async {
    await apiClient.delete(
      '/api/connections/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }

  Future<ConnectionTestResult> testConnection(String token, String id) async {
    final response = await apiClient.post(
      '/api/connections/${Uri.encodeComponent(id)}/test',
      gaToken: token,
    );
    return ConnectionTestResult.fromJson(response.json);
  }

  Future<List<ConnectionTestResult>> testAllConnections(
    String token, {
    List<String>? ids,
  }) async {
    final body = ids == null || ids.isEmpty
        ? null
        : <String, dynamic>{'ids': ids};
    final response = await apiClient.post(
      '/api/connections/test-all',
      gaToken: token,
      body: body,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ConnectionTestResult.fromJson(item))
        .toList();
  }
}
