import 'dart:convert';

import '../../../core/network/api_repository.dart';
import '../../../models/knowledge/knowledge_models.dart';

class KnowledgeRepository extends ApiRepository {
  KnowledgeRepository({required super.apiClient});

  Future<List<KnowledgeItem>> listItems(
    String token, {
    String? type,
    String? groupId,
    bool includeInactive = false,
  }) async {
    final params = <String>[];
    if (type != null && type.isNotEmpty) {
      params.add('type=${Uri.encodeQueryComponent(type)}');
    }
    if (groupId != null && groupId.isNotEmpty) {
      params.add('group_id=${Uri.encodeQueryComponent(groupId)}');
    }
    if (includeInactive) {
      params.add('include_inactive=true');
    }
    final query = params.isEmpty ? '' : '?${params.join('&')}';
    final response = await apiClient.get(
      '/api/knowledge$query',
      gaToken: token,
      cache: true,
    );
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
    List<String> labels = const ['private'],
  }) async {
    final response = await apiClient.post(
      '/api/knowledge/text',
      gaToken: token,
      body: {
        'title': title,
        'content': content,
        'source': source == null || source.trim().isEmpty
            ? title
            : source.trim(),
        'labels': labels,
      },
    );
    return response.json;
  }

  Future<Map<String, dynamic>> addUrl(
    String token, {
    required String url,
    String? title,
    List<String> labels = const ['private'],
  }) async {
    final response = await apiClient.post(
      '/api/knowledge/url',
      gaToken: token,
      body: {
        'url': url,
        'title': title?.trim().isEmpty == true ? null : title?.trim(),
        'labels': labels,
      },
    );
    return response.json;
  }

  Future<Map<String, dynamic>> uploadDocument(
    String token, {
    required String fileName,
    required List<int> fileBytes,
    List<String> labels = const ['private'],
  }) async {
    final response = await apiClient.postMultipart(
      '/api/knowledge/document',
      fieldName: 'file',
      fileName: fileName,
      fileBytes: fileBytes,
      fields: {'labels': jsonEncode(labels)},
      gaToken: token,
    );
    return response.json;
  }

  Future<void> deleteItem(String token, String id) async {
    await apiClient.delete(
      '/api/knowledge/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }

  Future<void> setItemActive(String token, String id, bool active) =>
      setActive(token, 'knowledge', id, active);
}
