import 'dart:typed_data';

import '../../../core/network/api_repository.dart';
import '../../../models/agents/agent_models.dart';

class AgentsRepository extends ApiRepository {
  AgentsRepository({required super.apiClient});

  Future<List<AgentItem>> listAgents(String token, {String? groupId}) async {
    final query = groupId == null || groupId.isEmpty
        ? ''
        : '&group_id=${Uri.encodeComponent(groupId)}';
    final response = await apiClient.get(
      '/api/agents?scope=all$query',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => AgentItem(raw: item))
        .toList();
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
