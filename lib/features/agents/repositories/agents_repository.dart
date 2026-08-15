import 'dart:typed_data';

import '../../../core/network/api_repository.dart';
import '../../../core/network/page_result.dart';
import '../../../models/agents/agent_models.dart';

class AgentsRepository extends ApiRepository {
  AgentsRepository({required super.apiClient});

  Future<List<AgentItem>> listAgents(
    String token, {
    String? groupId,
    bool includeInactive = false,
  }) async {
    final items = <AgentItem>[];
    var offset = 0;
    while (true) {
      final page = await listAgentPage(
        token,
        groupId: groupId,
        includeInactive: includeInactive,
        limit: 100,
        offset: offset,
      );
      items.addAll(page.items);
      if (!page.hasMore || page.items.isEmpty) return items;
      offset += page.items.length;
    }
  }

  Future<PageResult<AgentItem>> listAgentPage(
    String token, {
    String? groupId,
    bool includeInactive = false,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri(
      path: '/api/agents',
      queryParameters: {
        'scope': 'all',
        if (groupId != null && groupId.isNotEmpty) 'group_id': groupId,
        if (includeInactive) 'include_inactive': 'true',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final response = await apiClient.get(
      uri.toString(),
      gaToken: token,
      cache: false,
    );
    return PageResult.fromResponse(response, (item) => AgentItem(raw: item));
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
  Future<({Uint8List bytes, String? filename})> exportAgent(
    String token,
    String id,
    String format,
  ) async {
    return apiClient.getBytes(
      '/api/agents/${Uri.encodeComponent(id)}/export/${Uri.encodeComponent(format)}',
      gaToken: token,
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
