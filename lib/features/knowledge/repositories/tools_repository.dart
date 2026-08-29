import '../../../core/network/scoped_resource_repository.dart';
import '../../../models/tools/tool_models.dart';

/// Tools: `/api/tools/<scope>/<id>`, más la subida y descarga del binario de
/// las tools `cpp`, que es lo único que este recurso no comparte con skills y
/// prompts.
class ToolsRepository extends ScopedResourceRepository<ToolItem> {
  ToolsRepository({required super.apiClient})
    : super(basePath: 'tools', parse: _asTool);

  static ToolItem _asTool(Map<String, dynamic> raw) => ToolItem(raw: raw);

  Future<List<ToolItem>> listTools(
    String token, {
    String scope = 'all',
    String? groupId,
  }) => list(token, scope: scope, groupId: groupId);

  Future<Map<String, dynamic>> getTool(String token, String scope, String id) =>
      get(token, scope, id);

  Future<Map<String, dynamic>> saveTool(
    String token,
    String scope,
    Map<String, dynamic> payload,
  ) => save(token, scope, payload);

  Future<void> deleteTool(String token, String scope, String id) =>
      remove(token, scope, id);

  Future<void> setToolActive(
    String token,
    String scope,
    String id,
    bool active,
  ) => setActive(token, 'tools/${Uri.encodeComponent(scope)}', id, active);

  /// Sube el binario de una tool `cpp`, segundo paso del flujo en dos pasos
  /// (`POST /api/tools/{scope}` para los metadatos, luego este endpoint) —
  /// mismo mecanismo de multipart que `KnowledgeRepository.uploadDocument`.
  Future<Map<String, dynamic>> uploadToolBinaryStream(
    String token,
    String scope,
    String toolId, {
    required String fileName,
    required Stream<List<int>> Function() fileStream,
    required int fileLength,
  }) async {
    final response = await apiClient.postMultipartStream(
      '/api/tools/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(toolId)}/binary',
      fieldName: 'file',
      fileName: fileName,
      fileStream: fileStream,
      fileLength: fileLength,
      gaToken: token,
    );
    return response.json;
  }

  Future<
    ({
      Stream<List<int>> stream,
      String? filename,
      int? contentLength,
      String? sha256,
    })
  >
  downloadToolBinaryStream(
    String token,
    String scope,
    String toolId,
  ) => apiClient.getByteStream(
    '/api/tools/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(toolId)}/binary',
    gaToken: token,
  );
}
