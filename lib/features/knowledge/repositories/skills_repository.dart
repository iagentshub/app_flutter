import '../../../core/network/api_client.dart';
import '../../../models/skills/skill_models.dart';

class SkillsRepository {
  SkillsRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<SkillItem>> listSkills(
    String token, {
    String scope = 'all',
    String? groupId,
  }) async {
    final query = groupId == null || groupId.isEmpty
        ? ''
        : '&group_id=${Uri.encodeQueryComponent(groupId)}';
    final response = await apiClient.get(
      '/api/skills?scope=$scope$query',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => SkillItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getSkill(
    String token,
    String scope,
    String id,
  ) async {
    final response = await apiClient.get(
      '/api/skills/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> saveSkill(
    String token,
    String scope,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/skills/${Uri.encodeComponent(scope)}',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deleteSkill(String token, String scope, String id) async {
    await apiClient.delete(
      '/api/skills/${Uri.encodeComponent(scope)}/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }
}
