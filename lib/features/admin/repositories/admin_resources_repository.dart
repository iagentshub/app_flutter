import '../../../core/network/api_repository.dart';
import '../../../models/admin/admin_explore_models.dart';

/// Operaciones genéricas por tipo de recurso (grafo de contenido,
/// reasignación de dueño) más el borrado administrativo de los tipos que no
/// tienen suficiente superficie propia para justificar su propio
/// repositorio (orquestaciones, skills, prompts, memoria) — a diferencia de
/// usuarios/grupos/agentes/conexiones/knowledge, que sí lo tienen.
class AdminResourcesRepository extends ApiRepository {
  AdminResourcesRepository({required super.apiClient});

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

  // ── Tools ─────────────────────────────────────────────────────────────

  Future<void> deleteAdminTool(String token, String toolId) async {
    await apiClient.delete(
      '/api/admin/tools/${Uri.encodeComponent(toolId)}',
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
}
