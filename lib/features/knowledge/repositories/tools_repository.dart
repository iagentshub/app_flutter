import 'dart:typed_data';

import '../../../core/network/api_repository.dart';
import '../../../models/tools/tool_models.dart';

class ToolsRepository extends ApiRepository {
  ToolsRepository({required super.apiClient});

  Future<List<ToolItem>> listTools(
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
      '/api/tools?scope=$scope$query$inactive',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ToolItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getTool(
    String token,
    String scope,
    String id,
  ) async {
    final response = await apiClient.get(
      '/api/tools/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> saveTool(
    String token,
    String scope,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/tools/${Uri.encodeComponent(scope)}',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deleteTool(String token, String scope, String id) async {
    await apiClient.delete(
      '/api/tools/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }

  Future<void> setToolActive(String token, String id, bool active) =>
      setActive(token, 'tools', id, active);

  /// Sube el binario de una tool `cpp`, segundo paso del flujo en dos pasos
  /// (`POST /api/tools/{scope}` para los metadatos, luego este endpoint) —
  /// mismo mecanismo de multipart que `KnowledgeRepository.uploadDocument`.
  Future<Map<String, dynamic>> uploadToolBinary(
    String token,
    String scope,
    String toolId, {
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final response = await apiClient.postMultipart(
      '/api/tools/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(toolId)}/binary',
      fieldName: 'file',
      fileName: fileName,
      fileBytes: fileBytes,
      gaToken: token,
    );
    return response.json;
  }

  /// Descarga el binario de una tool `cpp` para guardarlo localmente.
  Future<({Uint8List bytes, String? filename})> downloadToolBinary(
    String token,
    String scope,
    String toolId,
  ) async {
    return apiClient.getBytes(
      '/api/tools/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(toolId)}/binary',
      gaToken: token,
    );
  }
}
