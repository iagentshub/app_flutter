import 'dart:convert';

import '../../../core/network/api_repository.dart';
import '../../../core/network/page_result.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../models/local_knowledge_file.dart';

class KnowledgeRepository extends ApiRepository {
  KnowledgeRepository({required super.apiClient});

  Future<List<KnowledgeItem>> listItems(
    String token, {
    String? type,
    String? groupId,
  }) async {
    final items = <KnowledgeItem>[];
    var offset = 0;
    while (true) {
      final page = await listItemPage(
        token,
        type: type,
        groupId: groupId,
        limit: 100,
        offset: offset,
      );
      items.addAll(page.items);
      if (!page.hasMore || page.items.isEmpty) return items;
      offset += page.items.length;
    }
  }

  Future<PageResult<KnowledgeItem>> listItemPage(
    String token, {
    String? type,
    String? groupId,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri(
      path: '/api/knowledge',
      queryParameters: {
        if (type != null && type.isNotEmpty) 'type': type,
        if (groupId != null && groupId.isNotEmpty) 'group_id': groupId,
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final response = await apiClient.get(
      uri.toString(),
      gaToken: token,
      cache: false,
    );
    return PageResult.fromResponse(
      response,
      (item) => KnowledgeItem(raw: item),
    );
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
      timeout: const Duration(minutes: 5),
    );
    return response.json;
  }

  Future<List<KnowledgePack>> listPacks(String token, {String? groupId}) async {
    final query = groupId == null || groupId.isEmpty
        ? ''
        : '?group_id=${Uri.encodeQueryComponent(groupId)}';
    final response = await apiClient.get(
      '/api/knowledge/packs$query',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((raw) => KnowledgePack(raw: raw))
        .toList();
  }

  Future<KnowledgePack> uploadPack(
    String token, {
    required String name,
    required String description,
    required List<LocalKnowledgeFile> files,
    required String sourceMode,
    List<String> labels = const ['private'],
  }) async {
    final response = await apiClient.postMultipartFiles(
      '/api/knowledge/packs',
      fieldName: 'files',
      files: [
        for (final file in files)
          (
            fileName: file.name,
            bytes: sourceMode == 'reference'
                ? const <int>[]
                : file.bytes.toList(),
          ),
      ],
      fields: {
        'name': name,
        'description': description,
        'paths': jsonEncode(files.map((file) => file.relativePath).toList()),
        'sizes': jsonEncode(files.map((file) => file.sizeBytes).toList()),
        'checksums': jsonEncode(
          files.map((file) => file.resolvedChecksum).toList(),
        ),
        'mime_types': jsonEncode(
          files.map((file) => file.resolvedMimeType).toList(),
        ),
        'source_mode': sourceMode,
        'labels': jsonEncode(labels),
      },
      gaToken: token,
      timeout: const Duration(minutes: 5),
    );
    return KnowledgePack(raw: response.json);
  }

  Future<KnowledgePack> createPackUploadSession(
    String token, {
    required String name,
    required String description,
    required String sourceMode,
    required List<String> labels,
    required int totalFiles,
  }) async {
    final response = await apiClient.post(
      '/api/knowledge/packs/upload-sessions',
      gaToken: token,
      body: {
        'name': name,
        'description': description,
        'source_mode': sourceMode,
        'labels': labels,
        'total_files': totalFiles,
      },
    );
    return KnowledgePack(raw: response.json);
  }

  Future<void> uploadPackSessionFile(
    String token, {
    required String sessionId,
    required LocalKnowledgeFile file,
    required bool referenceOnly,
    required void Function(double progress) onProgress,
  }) async {
    await apiClient.postMultipartWithProgress(
      '/api/knowledge/packs/upload-sessions/'
      '${Uri.encodeComponent(sessionId)}/files',
      fieldName: 'file',
      fileName: file.name,
      fileBytes: referenceOnly ? const <int>[] : file.bytes.toList(),
      fields: {
        'relative_path': file.relativePath,
        'reported_size': '${file.sizeBytes}',
        'reported_checksum': file.resolvedChecksum,
        'reported_mime_type': file.resolvedMimeType,
        if (file.modifiedAt != null)
          'reported_modified_at': '${file.modifiedAt}',
      },
      gaToken: token,
      timeout: const Duration(minutes: 5),
      onProgress: onProgress,
    );
  }

  Future<KnowledgePack> completePackUploadSession(
    String token,
    String sessionId,
  ) async {
    final response = await apiClient.post(
      '/api/knowledge/packs/upload-sessions/'
      '${Uri.encodeComponent(sessionId)}/complete',
      gaToken: token,
    );
    return KnowledgePack(raw: response.json);
  }

  Future<void> cancelPackUploadSession(String token, String sessionId) async {
    await apiClient.delete(
      '/api/knowledge/packs/upload-sessions/'
      '${Uri.encodeComponent(sessionId)}',
      gaToken: token,
    );
  }

  Future<KnowledgePack> synchronizePack(
    String token, {
    required KnowledgePack pack,
    required List<LocalKnowledgeFile> files,
  }) async {
    final referenceOnly = pack.sourceMode == 'reference';
    final manifest = [
      for (final file in files)
        {
          'relative_path': file.relativePath,
          'size_bytes': file.sizeBytes,
          'checksum': file.resolvedChecksum,
          'mime_type': file.resolvedMimeType,
          if (file.modifiedAt != null) 'modified_at': file.modifiedAt,
        },
    ];
    final comparison = await apiClient.post(
      '/api/knowledge/packs/${Uri.encodeComponent(pack.id)}/sync-manifest',
      gaToken: token,
      body: {'files': manifest},
    );
    final rawUploadPaths = comparison.json['upload_paths'];
    final uploadPaths = rawUploadPaths is List
        ? rawUploadPaths.map((value) => '$value').toSet()
        : files.map((file) => file.relativePath).toSet();
    final changedFiles = referenceOnly
        ? const <LocalKnowledgeFile>[]
        : files
              .where((file) => uploadPaths.contains(file.relativePath))
              .toList();
    final response = await apiClient.postMultipartFiles(
      '/api/knowledge/packs/${Uri.encodeComponent(pack.id)}/sync',
      fieldName: 'files',
      files: [
        for (final file in changedFiles)
          (fileName: file.name, bytes: file.bytes.toList()),
      ],
      fields: {
        'paths': jsonEncode(
          changedFiles.map((file) => file.relativePath).toList(),
        ),
        'sizes': jsonEncode(
          changedFiles.map((file) => file.sizeBytes).toList(),
        ),
        'manifest': jsonEncode(manifest),
      },
      gaToken: token,
      timeout: const Duration(minutes: 5),
    );
    return KnowledgePack(raw: response.json);
  }

  Future<KnowledgePack> getPack(String token, String id) async {
    final response = await apiClient.get(
      '/api/knowledge/packs/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return KnowledgePack(raw: response.json);
  }

  Future<void> deletePack(String token, String id) async {
    await apiClient.delete(
      '/api/knowledge/packs/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }

  Future<void> updatePack(
    String token,
    String id, {
    required String name,
    required String description,
    required List<String> labels,
  }) async {
    await apiClient.put(
      '/api/knowledge/packs/${Uri.encodeComponent(id)}',
      gaToken: token,
      body: {'name': name, 'description': description, 'labels': labels},
    );
  }

  Future<void> updateItem(
    String token,
    String id, {
    required String name,
    required List<String> labels,
  }) async {
    await apiClient.put(
      '/api/knowledge/${Uri.encodeComponent(id)}',
      gaToken: token,
      body: {'name': name, 'labels': labels},
    );
  }

  Future<void> deleteItem(String token, String id) async {
    await apiClient.delete(
      '/api/knowledge/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }
}
