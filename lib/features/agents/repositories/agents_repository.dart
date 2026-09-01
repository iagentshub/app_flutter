import 'dart:typed_data';

import '../../../core/network/api_repository.dart';
import '../../../core/network/cursor_page_collector.dart';
import '../../../core/network/page_result.dart';
import '../../../models/agents/agent_models.dart';

class AgentsRepository extends ApiRepository {
  AgentsRepository({required super.apiClient});

  Future<List<AgentItem>> listAgents(
    String token, {
    String? groupId,
    bool includeInactive = false,
  }) => collectCursorPages(
    (cursor) => listAgentPage(
      token,
      groupId: groupId,
      includeInactive: includeInactive,
      limit: 100,
      cursor: cursor,
    ),
  );

  Future<PageResult<AgentItem>> listAgentPage(
    String token, {
    String? groupId,
    bool includeInactive = false,
    int limit = 50,
    String? cursor,
  }) async {
    final uri = Uri(
      path: '/api/v2/agents',
      queryParameters: {
        'scope': 'all',
        if (groupId != null && groupId.isNotEmpty) 'group_id': groupId,
        if (includeInactive) 'include_inactive': 'true',
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final response = await apiClient.get(
      uri.toString(),
      gaToken: token,
      cache: false,
    );
    return PageResult.fromCursorV2Response(
      response,
      (item) => AgentItem(raw: item),
    );
  }

  Future<Map<String, dynamic>> getAgent(String token, String id) async {
    final response = await apiClient.get(
      '/api/agents/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> saveAgent(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/agents',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deleteAgent(String token, String id) async {
    await apiClient.delete(
      '/api/agents/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }

  Future<void> setAgentActive(String token, String id, bool active) =>
      setActive(token, 'agents', id, active);

  /// Exporta el agente en el formato dado (openai/claude/github/mcp) como un
  /// paquete .zip con el propio agente, sus skills, knowledge y memoria.
  Future<({Uint8List bytes, String? filename, bool complete, int warningCount})>
  exportAgent(String token, String id, String format) async {
    final result = await apiClient.getBytes(
      '/api/agents/${Uri.encodeComponent(id)}/export/${Uri.encodeComponent(format)}',
      gaToken: token,
    );
    return (
      bytes: result.bytes,
      filename: result.filename,
      complete:
          result.headers['x-iagentshub-export-complete']?.toLowerCase() !=
          'false',
      warningCount:
          int.tryParse(
            result.headers['x-iagentshub-export-warning-count'] ?? '',
          ) ??
          0,
    );
  }

  /// Conexión que este usuario prefiere para este agente (p. ej. un agente
  /// compartido cuya conexión por defecto no le pertenece), o `null` si usa
  /// la conexión predeterminada del agente.
  Future<String?> getPreferredConnection(String token, String agentId) async {
    final response = await apiClient.get(
      '/api/agents/${Uri.encodeComponent(agentId)}/preferences',
      gaToken: token,
    );
    return response.json['connection_id'] as String?;
  }

  Future<void> setPreferredConnection(
    String token,
    String agentId,
    String? connectionId,
  ) async {
    await apiClient.put(
      '/api/agents/${Uri.encodeComponent(agentId)}/preferences',
      gaToken: token,
      body: {'connection_id': connectionId},
    );
  }
}
