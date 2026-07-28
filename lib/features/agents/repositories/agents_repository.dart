import '../../../core/network/api_client.dart';
import '../../../models/agents/agent_models.dart';

class AgentsRepository {
  AgentsRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<AgentItem>> listAgents(String token) async {
    final response = await apiClient.get('/api/agents?scope=all', gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => AgentItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getAgent(String token, String id) async {
    final response = await apiClient.get('/api/agents/${Uri.encodeComponent(id)}', gaToken: token);
    return response.json;
  }

  Future<Map<String, dynamic>> saveAgent(String token, Map<String, dynamic> payload) async {
    final response = await apiClient.post('/api/agents', gaToken: token, body: payload);
    return response.json;
  }

  Future<void> deleteAgent(String token, String id) async {
    await apiClient.delete('/api/agents/${Uri.encodeComponent(id)}', gaToken: token);
  }
}
