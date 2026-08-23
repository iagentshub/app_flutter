import '../../../core/network/api_repository.dart';
import '../models/resource_execution.dart';

class ResourceExecutionsRepository extends ApiRepository {
  ResourceExecutionsRepository({required super.apiClient});

  Future<List<ResourceExecution>> list(String token) async {
    final response = await apiClient.get(
      '/api/resource-executions',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(ResourceExecution.fromJson)
        .toList();
  }
}
