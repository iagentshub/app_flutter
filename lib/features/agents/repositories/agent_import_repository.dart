import 'dart:convert';
import 'dart:typed_data';

import '../../../core/network/api_repository.dart';
import '../../../models/agents/agent_import_models.dart';
import '../../../models/agents/agent_resource_catalog.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/tools/tool_models.dart';
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

  Future<AgentResourceOptionPage> searchCatalog(
    String token,
    AgentResourceType type, {
    String query = '',
    int offset = 0,
    int limit = 50,
  }) async {
    final uri = Uri(
      path: '/api/agents/import/catalog/${type.apiValue}',
      queryParameters: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final response = await apiClient.get(uri.toString(), gaToken: token);
    return AgentResourceOptionPage.fromJson(response.json, type);
  }

  Future<AgentResourceCatalog> resolveCatalog(
    String token,
    Map<AgentResourceType, Iterable<String>> ids,
  ) async {
    final response = await apiClient.post(
      '/api/agents/import/catalog/resolve',
      body: {
        'resources': {
          for (final entry in ids.entries)
            entry.key.apiValue: entry.value.toSet().toList(),
        },
      },
      gaToken: token,
      sideEffect: false,
    );
    final json = response.json;
    List<Map<String, dynamic>> rows(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();
    return AgentResourceCatalog(
      skills: rows('skill').map((raw) => SkillItem(raw: raw)).toList(),
      knowledge: rows('knowledge')
          .map((raw) => KnowledgeItem(raw: raw))
          .toList(),
      packs: rows('knowledge_pack')
          .map((raw) => KnowledgePack(raw: raw))
          .toList(),
      prompts: rows('prompt').map((raw) => PromptItem(raw: raw)).toList(),
      tools: rows('tool').map((raw) => ToolItem(raw: raw)).toList(),
    );
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
    required String? sessionId,
    required AgentDirectoryImportOptions options,
  }) async {
    final fields = <String, String>{
      'paths': sessionId == null
          ? jsonEncode(files.map((file) => file.relativePath).toList())
          : '[]',
      'options': jsonEncode(options.toJson()),
    };
    if (sessionId case final value?) fields['session_id'] = value;
    final response = await apiClient.postMultipartFiles(
      '/api/agents/import/directory/apply',
      fieldName: 'files',
      files: sessionId == null ? _multipartFiles(files) : const [],
      fields: fields,
      gaToken: token,
    );
    return AgentDirectoryImportResult.fromJson(response.json);
  }

  List<({String fileName, List<int> bytes})> _multipartFiles(
    List<LocalKnowledgeFile> files,
  ) => [for (final file in files) (fileName: file.name, bytes: file.bytes)];
}
