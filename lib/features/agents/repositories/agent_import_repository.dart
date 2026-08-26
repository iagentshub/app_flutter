import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_repository.dart';
import '../../../models/agents/agent_import_models.dart';
import '../../knowledge/models/local_knowledge_file.dart';

class AgentImportRepository extends ApiRepository {
  AgentImportRepository({required super.apiClient});

  Future<AgentImportPreview> previewFile(
    String token, {
    required String fileName,
    required Uint8List bytes,
  }) async {
    final response = await apiClient.postMultipartPreview(
      '/api/agents/import/preview',
      fieldName: 'file',
      fileName: fileName,
      fileBytes: bytes,
      gaToken: token,
    );
    return AgentImportPreview.fromJson(response.json);
  }

  Future<AgentDirectoryImportPlan> previewDirectory(
    String token, {
    required List<LocalKnowledgeFile> files,
  }) async {
    final response = await apiClient.postMultipartFiles(
      '/api/agents/import/directory/preview',
      fieldName: 'files',
      files: _multipartFiles(files),
      fields: {
        'paths': jsonEncode(files.map((file) => file.relativePath).toList()),
      },
      gaToken: token,
      sideEffect: false,
    );
    return AgentDirectoryImportPlan.fromJson(response.json);
  }

  Future<AgentDirectoryImportResult> applyDirectory(
    String token, {
    required List<LocalKnowledgeFile> files,
    required AgentDirectoryImportOptions options,
  }) async {
    final response = await apiClient.postMultipartFiles(
      '/api/agents/import/directory/apply',
      fieldName: 'files',
      files: _multipartFiles(files),
      fields: {
        'paths': jsonEncode(files.map((file) => file.relativePath).toList()),
        'options': jsonEncode(options.toJson()),
      },
      gaToken: token,
    );
    return AgentDirectoryImportResult.fromJson(response.json);
  }

  List<({String fileName, List<int> bytes})> _multipartFiles(
    List<LocalKnowledgeFile> files,
  ) => [for (final file in files) (fileName: file.name, bytes: file.bytes)];
}
