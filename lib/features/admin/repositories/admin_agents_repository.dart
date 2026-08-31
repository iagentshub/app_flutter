import '../../../core/network/api_repository.dart';

/// Gestión de agentes desde Admin (`/api/v2/admin/agents`): listado, edición
/// administrativa y borrado (con `scope` para distinguir privados/públicos).
class AdminAgentsRepository extends ApiRepository {
  AdminAgentsRepository({required super.apiClient});

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
