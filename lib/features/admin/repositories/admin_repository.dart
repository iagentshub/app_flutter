import '../../../core/network/api_client.dart';

class AdminStats {
  const AdminStats({required this.raw});

  final Map<String, dynamic> raw;

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int get usersTotal => _asInt(raw['users_total']);
  int get usersActive => _asInt(raw['users_active']);
  int get usersVerified => _asInt(raw['users_verified']);
  int get connectionsTotal => _asInt(raw['connections_total']);
  int get workflowsTotal => _asInt(raw['workflows_total']);
  int get knowledgeTotal => _asInt(raw['knowledge_total']);
  int get conversationsTotal => _asInt(raw['conversations_total']);
  int get agentsPublic => _asInt(raw['agents_public']);
  int get agentsPrivate => _asInt(raw['agents_private']);
}

class AdminRepository {
  AdminRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<AdminStats> getStats(String token) async {
    final response = await apiClient.get('/api/admin/stats', gaToken: token, cache: true);
    return AdminStats(raw: response.json);
  }

  Future<List<Map<String, dynamic>>> listUsers(
    String token, {
    String query = '',
    String role = '',
    String active = '',
    String verified = '',
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (role.trim().isNotEmpty) 'role': role.trim(),
      if (active.trim().isNotEmpty) 'active': active.trim(),
      if (verified.trim().isNotEmpty) 'verified': verified.trim(),
    };
    final path = Uri(path: '/api/admin/users', queryParameters: params).toString();
    final response = await apiClient.get(path, gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setUserActive(String token, String username, bool isActive) async {
    await apiClient.patch(
      '/api/admin/users/${Uri.encodeComponent(username)}',
      gaToken: token,
      body: {'is_active': isActive},
    );
  }

  Future<List<Map<String, dynamic>>> listWorkspaces(String token) async {
    final response = await apiClient.get('/api/admin/workspaces', gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setWorkspaceStatus(String token, String workspaceId, String status) async {
    await apiClient.post(
      '/api/admin/workspaces/${Uri.encodeComponent(workspaceId)}/status',
      gaToken: token,
      body: {'status': status},
    );
  }

  Future<void> deleteWorkspace(String token, String workspaceId) async {
    await apiClient.delete('/api/admin/workspaces/${Uri.encodeComponent(workspaceId)}', gaToken: token);
  }
}
