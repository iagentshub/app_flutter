import '../../../core/network/api_repository.dart';
import '../../../models/admin/admin_explore_models.dart';

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

  int get requestsToday => _asInt(raw['requests_today']);
  int get errorsToday => _asInt(raw['errors_today']);
  double get failureRatePct =>
      (raw['failure_rate_pct'] as num?)?.toDouble() ?? 0.0;
  int get avgLatencyMs => _asInt(raw['avg_latency_ms']);
  String? get topErrorEndpoint => raw['top_error_endpoint'] as String?;
  int get topErrorCount => _asInt(raw['top_error_count']);

  // Salud del host — None cuando el backend no pudo leer la métrica (p.ej.
  // memoria fuera de Linux); ver _server_health() en admin.py.
  double? get diskUsedPct => (raw['disk_used_pct'] as num?)?.toDouble();
  double? get diskUsedGb => (raw['disk_used_gb'] as num?)?.toDouble();
  double? get diskTotalGb => (raw['disk_total_gb'] as num?)?.toDouble();
  double? get memoryUsedPct => (raw['memory_used_pct'] as num?)?.toDouble();
  double? get memoryUsedGb => (raw['memory_used_gb'] as num?)?.toDouble();
  double? get memoryTotalGb => (raw['memory_total_gb'] as num?)?.toDouble();
  double? get cpuLoadPct => (raw['cpu_load_pct'] as num?)?.toDouble();
  int? get cpuCores => raw['cpu_cores'] == null ? null : _asInt(raw['cpu_cores']);
}

class AdminRepository extends ApiRepository {
  AdminRepository({required super.apiClient});

  Future<AdminExploreResult> explore(String token) async {
    const pageSize = 200;
    var offset = 0;
    var total = 0;
    var counts = const <AdminResourceType, int>{};
    final items = <AdminExploreItem>[];
    do {
      final response = await apiClient.get(
        '/api/admin/explore?limit=$pageSize&offset=$offset',
        gaToken: token,
      );
      final page = AdminExploreResult.fromJson(response.json);
      total = page.total;
      counts = page.counts;
      items.addAll(page.items);
      offset += page.items.length;
      if (page.items.isEmpty) break;
    } while (items.length < total);
    return AdminExploreResult(items: items, total: total, counts: counts);
  }

  Future<AdminResourceGraph> getResourceGraph(
    String token,
    AdminResourceType type,
    String resourceId,
  ) async {
    final response = await apiClient.get(
      '/api/admin/resources/${Uri.encodeComponent(type.wireName)}/${Uri.encodeComponent(resourceId)}/graph',
      gaToken: token,
    );
    return AdminResourceGraph.fromJson(response.json);
  }

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
      body: {'username': newOwner},
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
    required String username,
    required String email,
    required String password,
    String? displayName,
    String role = 'standard',
  }) async {
    await apiClient.post(
      '/api/admin/users',
      gaToken: token,
      body: {
        'username': username.trim().toLowerCase(),
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

  // ── Skills ────────────────────────────────────────────────────────────

  Future<void> deleteAdminSkill(String token, String skillId) async {
    await apiClient.delete(
      '/api/admin/skills/${Uri.encodeComponent(skillId)}',
      gaToken: token,
    );
  }

  // ── Prompts ───────────────────────────────────────────────────────────

  Future<void> deleteAdminPrompt(String token, String promptId) async {
    await apiClient.delete(
      '/api/admin/prompts/${Uri.encodeComponent(promptId)}',
      gaToken: token,
    );
  }

  // ── Memoria ───────────────────────────────────────────────────────────

  Future<void> deleteAdminMemory(String token, String memoryId) async {
    await apiClient.delete(
      '/api/admin/memory/${Uri.encodeComponent(memoryId)}',
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

  Future<Map<String, dynamic>> getUserSettings(String token) async {
    final response = await apiClient.get('/api/settings', gaToken: token);
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

  Future<Map<String, dynamic>> triggerUpdateNow(String token) async {
    final response = await apiClient.post(
      '/api/admin/update-now',
      gaToken: token,
    );
    return response.json;
  }

  // ── Banners de notificación ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> listNotificationBanners(
    String token,
  ) async {
    final response = await apiClient.get(
      '/api/settings/notification-banners',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<Map<String, dynamic>> createNotificationBanner(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/settings/notification-banners',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> updateNotificationBanner(
    String token,
    String bannerId,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.put(
      '/api/settings/notification-banners/${Uri.encodeComponent(bannerId)}',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deleteNotificationBanner(String token, String bannerId) async {
    await apiClient.delete(
      '/api/settings/notification-banners/${Uri.encodeComponent(bannerId)}',
      gaToken: token,
    );
  }
}
