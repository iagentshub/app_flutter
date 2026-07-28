import '../../../core/network/api_client.dart';
import '../../../models/dashboard/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<DashboardSummary> fetchSummary({required String gaToken}) async {
    final agentsResponse = await _apiClient.get('/api/agents', gaToken: gaToken);
    final connectionsResponse = await _apiClient.get('/api/connections', gaToken: gaToken);
    final knowledgeResponse = await _apiClient.get('/api/knowledge', gaToken: gaToken);
    final workflowsResponse = await _apiClient.get('/api/workflows', gaToken: gaToken);

    return DashboardSummary(
      agents: _countList(agentsResponse.body),
      connections: _countList(connectionsResponse.body),
      knowledge: _countList(knowledgeResponse.body),
      workflows: _countList(workflowsResponse.body),
    );
  }

  int _countList(Object? body) {
    if (body is List) return body.length;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data.length;
    }
    return 0;
  }
}
