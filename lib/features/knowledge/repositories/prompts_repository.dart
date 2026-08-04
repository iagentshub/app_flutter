import '../../../core/network/api_repository.dart';
import '../../../models/prompts/prompt_models.dart';

class PromptsRepository extends ApiRepository {
  PromptsRepository({required super.apiClient});

  Future<List<PromptItem>> listPrompts(
    String token, {
    String scope = 'all',
    String? groupId,
    bool includeInactive = false,
  }) async {
    final query = groupId == null || groupId.isEmpty
        ? ''
        : '&group_id=${Uri.encodeQueryComponent(groupId)}';
    final inactive = includeInactive ? '&include_inactive=true' : '';
    final response = await apiClient.get(
      '/api/prompts?scope=$scope$query$inactive',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => PromptItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getPrompt(
    String token,
    String scope,
    String id,
  ) async {
    final response = await apiClient.get(
      '/api/prompts/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> savePrompt(
    String token,
    String scope,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/prompts/${Uri.encodeComponent(scope)}',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deletePrompt(String token, String scope, String id) async {
    await apiClient.delete(
      '/api/prompts/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }

  Future<void> setPromptActive(String token, String id, bool active) =>
      setActive(token, 'prompts', id, active);
}
