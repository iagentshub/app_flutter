import '../../../core/network/api_client.dart';
import '../../../models/knowledge/knowledge_models.dart';

class KnowledgeRepository {
  KnowledgeRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<KnowledgeItem>> listItems(String token, {String? type}) async {
    final query = type == null || type.isEmpty ? '' : '?type=${Uri.encodeQueryComponent(type)}';
    final response = await apiClient.get('/api/knowledge$query', gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => KnowledgeItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> addText(
    String token, {
    required String title,
    required String content,
    String? source,
  }) async {
    final response = await apiClient.post(
      '/api/knowledge/text',
      gaToken: token,
      body: {
        'title': title,
        'content': content,
        'source': source == null || source.trim().isEmpty ? title : source.trim(),
      },
    );
    return response.json;
  }

  Future<Map<String, dynamic>> addUrl(
    String token, {
    required String url,
    String? title,
  }) async {
    final response = await apiClient.post(
      '/api/knowledge/url',
      gaToken: token,
      body: {
        'url': url,
        'title': title?.trim().isEmpty == true ? null : title?.trim(),
      },
    );
    return response.json;
  }

  Future<Map<String, dynamic>> uploadDocument(
    String token, {
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final response = await apiClient.postMultipart(
      '/api/knowledge/document',
      fieldName: 'file',
      fileName: fileName,
      fileBytes: fileBytes,
      gaToken: token,
    );
    return response.json;
  }

  Future<void> deleteItem(String token, String id) async {
    await apiClient.delete('/api/knowledge/${Uri.encodeComponent(id)}', gaToken: token);
  }
}
