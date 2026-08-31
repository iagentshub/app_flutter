import '../../../core/network/api_repository.dart';
import '../../../models/admin/admin_explore_models.dart';
import '../../../shared/graph/resource_graph_builder.dart';

/// Operaciones genéricas por tipo de recurso (grafo de contenido,
/// reasignación de dueño) más el borrado administrativo de los tipos que no
/// tienen suficiente superficie propia para justificar su propio
/// repositorio (orquestaciones, skills, prompts, memoria) — a diferencia de
/// usuarios/grupos/agentes/conexiones/knowledge, que sí lo tienen.
class AdminResourcesRepository extends ApiRepository {
  AdminResourcesRepository({required super.apiClient});

  Future<GraphBuild> getResourceGraph(
    String token,
    AdminResourceType type,
    String resourceId,
  ) async {
    final response = await apiClient.get(
      '/api/admin/resources/${Uri.encodeComponent(type.wireName)}/${Uri.encodeComponent(resourceId)}/relations',
      gaToken: token,
    );
    return fromRelations(response.json);
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

  Future<void> deleteAdminWorkflow(String token, String workflowId) async {
    await apiClient.delete(
      '/api/admin/workflows/${Uri.encodeComponent(workflowId)}',
      gaToken: token,
    );
  }

  Future<void> deleteAdminLlmOrchestration(String token, String id) async {
    await apiClient.delete(
      '/api/admin/llm-orchestrations/${Uri.encodeComponent(id)}',
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

  Future<Map<String, dynamic>> getAdminTool(String token, String toolId) async {
    final response = await apiClient.get(
      '/api/admin/tools/${Uri.encodeComponent(toolId)}',
      gaToken: token,
    );
    return response.json;
  }

  Future<void> setAdminToolSecurity(
    String token,
    String toolId,
    String state,
  ) async {
    await apiClient.put(
      '/api/admin/tools/${Uri.encodeComponent(toolId)}/security',
      gaToken: token,
      body: {'state': state},
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
