import '../../../core/network/scoped_resource_repository.dart';
import '../../../models/prompts/prompt_models.dart';

/// Prompts: `/api/prompts/<scope>/<id>`.
///
/// Todo el contrato vive en [ScopedResourceRepository]; aquí solo quedan los
/// nombres de dominio.
class PromptsRepository extends ScopedResourceRepository<PromptItem> {
  PromptsRepository({required super.apiClient})
    : super(basePath: 'prompts', parse: _asPrompt);

  static PromptItem _asPrompt(Map<String, dynamic> raw) => PromptItem(raw: raw);

  Future<List<PromptItem>> listPrompts(
    String token, {
    String scope = 'all',
    String? groupId,
  }) => list(token, scope: scope, groupId: groupId);

  Future<Map<String, dynamic>> getPrompt(
    String token,
    String scope,
    String id,
  ) => get(token, scope, id);

  Future<Map<String, dynamic>> savePrompt(
    String token,
    String scope,
    Map<String, dynamic> payload,
  ) => save(token, scope, payload);

  Future<void> deletePrompt(String token, String scope, String id) =>
      remove(token, scope, id);

  Future<void> setPromptActive(
    String token,
    String scope,
    String id,
    bool active,
  ) => setActive(token, 'prompts/${Uri.encodeComponent(scope)}', id, active);
}
