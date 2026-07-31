import '../../../core/network/api_repository.dart';

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

class AdminRepository extends ApiRepository {
  AdminRepository({required super.apiClient});

  Future<AdminStats> getStats(String token) async {
    final response = await apiClient.get(
      '/api/admin/stats',
      gaToken: token,
      cache: true,
    );
    return AdminStats(raw: response.json);
  }

  /// Reasigna el propietario de un recurso (agente, skill, conexión,
  /// knowledge u orquestación) a otro usuario existente.
  Future<void> setResourceOwner(
    String token,
    String resourceType,
    String resourceId,
    String newOwner,
  ) async {
    await apiClient.put(
      '/api/admin/resources/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(resourceId)}/owner',
      gaToken: token,
      body: {'owner_id': newOwner},
    );
  }

  // ── Usuarios ──────────────────────────────────────────────────────────

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
    final path = Uri(
      path: '/api/admin/users',
      queryParameters: params,
    ).toString();
    final response = await apiClient.get(path, gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> patchUser(
    String token,
    String username, {
    String? role,
    bool? isActive,
    String? password,
  }) async {
    await apiClient.patch(
      '/api/admin/users/${Uri.encodeComponent(username)}',
      gaToken: token,
      body: {
        'role': ?role,
        'is_active': ?isActive,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
  }

  Future<void> setUserActive(
    String token,
    String username,
    bool isActive,
  ) async {
    await patchUser(token, username, isActive: isActive);
  }

  Future<void> createUser(
    String token, {
    required String email,
    required String password,
    String? displayName,
    String role = 'standard',
  }) async {
    await apiClient.post(
      '/api/admin/users',
      gaToken: token,
      body: {
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
        'role': role,
      },
    );
  }

  Future<void> deleteUser(String token, String username) async {
    await apiClient.delete(
      '/api/admin/users/${Uri.encodeComponent(username)}',
      gaToken: token,
    );
  }

  // ── Grupos (groups) ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listGroups(String token) async {
    final response = await apiClient.get(
      '/api/admin/groups',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setGroupStatus(
    String token,
    String groupId,
    String status,
  ) async {
    await apiClient.post(
      '/api/admin/groups/${Uri.encodeComponent(groupId)}/status',
      gaToken: token,
      body: {'status': status},
    );
  }

  Future<void> deleteGroup(String token, String groupId) async {
    await apiClient.delete(
      '/api/admin/groups/${Uri.encodeComponent(groupId)}',
      gaToken: token,
    );
  }

  // ── Agentes ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listAgents(String token) async {
    final response = await apiClient.get(
      '/api/admin/agents',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> updateAgent(
    String token,
    String agentId,
    Map<String, dynamic> payload,
  ) async {
    await apiClient.put(
      '/api/admin/agents/${Uri.encodeComponent(agentId)}',
      gaToken: token,
      body: payload,
    );
  }

  Future<void> deleteAgent(
    String token,
    String agentId, {
    String scope = 'private',
  }) async {
    await apiClient.delete(
      '/api/admin/agents/${Uri.encodeComponent(agentId)}?scope=${Uri.encodeComponent(scope)}',
      gaToken: token,
    );
  }

  // ── Conexiones ────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listAdminConnections(String token) async {
    final response = await apiClient.get(
      '/api/admin/connections',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> deleteAdminConnection(String token, String connectionId) async {
    await apiClient.delete(
      '/api/admin/connections/${Uri.encodeComponent(connectionId)}',
      gaToken: token,
    );
  }

  // ── Knowledge ─────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listAdminKnowledge(String token) async {
    final response = await apiClient.get(
      '/api/admin/knowledge',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> deleteAdminKnowledge(String token, String itemId) async {
    await apiClient.delete(
      '/api/admin/knowledge/${Uri.encodeComponent(itemId)}',
      gaToken: token,
    );
  }

  // ── Orquestaciones (workflows) ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> listAdminWorkflows(String token) async {
    final response = await apiClient.get(
      '/api/admin/workflows',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> deleteAdminWorkflow(String token, String workflowId) async {
    await apiClient.delete(
      '/api/admin/workflows/${Uri.encodeComponent(workflowId)}',
      gaToken: token,
    );
  }

  // ── Configuración de plataforma ──────────────────────────────────────

  Future<Map<String, dynamic>> getPlatformSettings(String token) async {
    final response = await apiClient.get(
      '/api/settings/platform',
      gaToken: token,
      cache: true,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> updatePlatformSettings(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.put(
      '/api/settings/platform',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> checkUpdate(String token) async {
    final response = await apiClient.get(
      '/api/admin/check-update',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> setAutoUpdate(String token, bool enabled) async {
    final response = await apiClient.put(
      '/api/admin/auto-update',
      gaToken: token,
      body: {'enabled': enabled},
    );
    return response.json;
  }
}
