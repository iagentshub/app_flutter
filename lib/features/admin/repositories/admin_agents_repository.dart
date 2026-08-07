import '../../../core/network/api_repository.dart';

/// Gestión de agentes desde Admin (`/api/admin/agents`): listado, edición
/// administrativa y borrado (con `scope` para distinguir privados/públicos).
class AdminAgentsRepository extends ApiRepository {
  AdminAgentsRepository({required super.apiClient});

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
}
