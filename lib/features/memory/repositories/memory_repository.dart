import '../../../core/network/api_client.dart';
import '../../../models/memory/memory_models.dart';

class MemoryRepository {
  MemoryRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<MemoryFileItem>> listFiles(String token) async {
    final response = await apiClient.get('/api/memory', gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => MemoryFileItem(raw: item))
        .toList();
  }

  Future<String> getFileContent(String token, String filename) async {
    final response = await apiClient.get('/api/memory/${Uri.encodeComponent(filename)}', gaToken: token);
    final data = response.json;
    return data['content'] as String? ?? '';
  }

  Future<Map<String, dynamic>> saveFile(String token, String filename, String content) async {
    final response = await apiClient.post(
      '/api/memory/${Uri.encodeComponent(filename)}',
      gaToken: token,
      body: {'content': content},
    );
    return response.json;
  }

  Future<void> deleteFile(String token, String filename) async {
    await apiClient.delete('/api/memory/${Uri.encodeComponent(filename)}', gaToken: token);
  }
}
