import '../../../core/network/api_repository.dart';
import '../../../models/workflows/llm_orchestration_models.dart';

class LlmOrchestrationsRepository extends ApiRepository {
  LlmOrchestrationsRepository({required super.apiClient});

  Future<List<LlmOrchestrationItem>> list(
    String token, {
    bool includeInactive = false,
  }) async {
    final query = includeInactive ? '?include_inactive=true' : '';
    final response = await apiClient.get(
      '/api/llm-orchestrations$query',
      gaToken: token,
      cache: false,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((raw) => LlmOrchestrationItem(raw: raw))
        .toList();
  }

  Future<Map<String, dynamic>> save(
    String token,
    Map<String, dynamic> payload,
  ) async => (await apiClient.post(
    '/api/llm-orchestrations',
    gaToken: token,
    body: payload,
  )).json;

  Future<void> delete(String token, String id) => apiClient.delete(
    '/api/llm-orchestrations/${Uri.encodeComponent(id)}',
    gaToken: token,
  );

  Future<void> setOrchestrationActive(String token, String id, bool active) =>
      setActive(token, 'llm-orchestrations', id, active);
}
