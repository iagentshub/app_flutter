import '../../../core/config/content_languages.dart';
import '../../../core/config/tool_runtimes.dart';
import '../../../models/tools/tool_models.dart';

class OfficialSource {
  const OfficialSource({
    required this.id,
    required this.name,
    required this.repositoryUrl,
    required this.provider,
    required this.repositoryPath,
    required this.trackingMode,
    required this.trackingRef,
    required this.resources,
    this.description = '',
    this.ownerId,
    this.defaultBranch = 'main',
    this.license = '',
    this.lastCommitSha,
    this.syncState = 'idle',
    this.lastSyncError,
    this.importMode = 'deterministic',
    this.llmConnectionId,
  });

  factory OfficialSource.fromJson(Map<String, dynamic> json) => OfficialSource(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    description: '${json['description'] ?? ''}',
    repositoryUrl: '${json['repository_url'] ?? ''}',
    provider: '${json['provider'] ?? 'github'}',
    repositoryPath: '${json['repository_path'] ?? ''}',
    ownerId: json['owner_id']?.toString(),
    defaultBranch: '${json['default_branch'] ?? 'main'}',
    trackingMode: '${json['tracking_mode'] ?? 'release'}',
    trackingRef: '${json['tracking_ref'] ?? 'main'}',
    license: '${json['license'] ?? ''}',
    lastCommitSha: json['last_commit_sha']?.toString(),
    syncState: '${json['sync_state'] ?? 'idle'}',
    lastSyncError: json['last_sync_error']?.toString(),
    importMode: '${json['import_mode'] ?? 'deterministic'}',
    llmConnectionId: json['llm_connection_id']?.toString(),
    resources: (json['resources'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false),
  );

  final String id;
  final String name;
  final String description;
  final String repositoryUrl;
  final String provider;
  final String repositoryPath;
  final String? ownerId;
  final String defaultBranch;
  final String trackingMode;
  final String trackingRef;
  final String license;
  final String? lastCommitSha;
  final String syncState;
  final String? lastSyncError;
  final String importMode;
  final String? llmConnectionId;
  final List<Map<String, dynamic>> resources;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'repository_url': repositoryUrl,
    'provider': provider,
    'repository_path': repositoryPath,
    'owner_id': ownerId,
    'default_branch': defaultBranch,
    'tracking_mode': trackingMode,
    'tracking_ref': trackingRef,
    'license': license,
    'last_commit_sha': lastCommitSha,
    'sync_state': syncState,
    'last_sync_error': lastSyncError,
    'import_mode': importMode,
    'llm_connection_id': llmConnectionId,
    'resources': resources,
  };
}

ToolLanguage? _componentToolLanguage(Map<String, dynamic> json) {
  final explicit = ToolLanguage.tryParseSupported(
    json['forced_tool_language'] ?? json['tool_language'],
  );
  return explicit ??
      ToolRuntimeCatalog.fromSourcePath('${json['source_path'] ?? ''}');
}

class ImportComponent {
  const ImportComponent({
    required this.id,
    required this.type,
    required this.name,
    required this.sourcePath,
    required this.state,
    required this.selected,
    required this.materializable,
    required this.dependencies,
    required this.variants,
    this.description = '',
    this.content = '',
    this.forcedType,
    this.language = '',
    this.toolLanguage,
    this.securityAccepted = false,
    this.securityBlocked = false,
    this.securityReviewRequired = false,
    this.relations = const [],
  });

  factory ImportComponent.fromJson(Map<String, dynamic> json) =>
      ImportComponent(
        id: '${json['component_id'] ?? ''}',
        type: '${json['component_type'] ?? 'unknown'}',
        name: '${json['name'] ?? ''}',
        description: '${json['description'] ?? ''}',
        sourcePath: '${json['source_path'] ?? ''}',
        content: '${json['content'] ?? ''}',
        state: '${json['state'] ?? 'new'}',
        selected: json['selected'] == true,
        materializable: json['materializable'] != false,
        dependencies: (json['dependencies'] as List? ?? const [])
            .map((item) => '$item')
            .toList(growable: false),
        variants: (json['variants'] as List? ?? const [])
            .map((item) => '$item')
            .toList(growable: false),
        forcedType: json['forced_type']?.toString(),
        language: ContentLanguages.normalizeLabel(
          json['forced_language'] ?? json['language'],
        ),
        toolLanguage: _componentToolLanguage(json),
        securityAccepted: json['security_accepted'] == true,
        securityBlocked: json['security_blocked'] == true,
        securityReviewRequired: json['security_review_required'] == true,
        relations: (json['relations'] as List? ?? const [])
            .whereType<Map>()
            .map(
              (item) => ImportRelation.fromJson(item.cast<String, dynamic>()),
            )
            .toList(growable: false),
      );

  final String id;
  final String type;
  final String name;
  final String description;
  final String sourcePath;
  final String content;
  final String state;
  final bool selected;
  final bool materializable;
  final List<String> dependencies;
  final List<String> variants;
  final String? forcedType;
  final String language;
  final ToolLanguage? toolLanguage;
  final bool securityAccepted;
  final bool securityBlocked;
  final bool securityReviewRequired;
  final List<ImportRelation> relations;

  String get effectiveType {
    final value = forcedType ?? type;
    return value == 'command' ? 'prompt' : value;
  }

  bool get omitted => !materializable && forcedType == null;
}

class ImportRelation {
  const ImportRelation({
    required this.targetId,
    required this.type,
    this.evidencePath = '',
    this.evidence = '',
  });

  factory ImportRelation.fromJson(Map<String, dynamic> json) => ImportRelation(
    targetId: '${json['target_id'] ?? ''}',
    type: '${json['relation_type'] ?? 'uses'}',
    evidencePath: '${json['evidence_path'] ?? ''}',
    evidence: '${json['evidence'] ?? ''}',
  );

  final String targetId;
  final String type;
  final String evidencePath;
  final String evidence;
}

class OfficialImportLlmConnection {
  const OfficialImportLlmConnection({
    required this.id,
    required this.name,
    required this.type,
    required this.model,
    required this.supportsChat,
  });

  factory OfficialImportLlmConnection.fromJson(Map<String, dynamic> json) =>
      OfficialImportLlmConnection(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? json['label'] ?? json['type'] ?? ''}',
        type: '${json['type'] ?? ''}'.toLowerCase(),
        model: '${json['model'] ?? ''}',
        supportsChat: json['supports_chat'] == true,
      );

  final String id;
  final String name;
  final String type;
  final String model;
  final bool supportsChat;

  bool get compatible => id.isNotEmpty && supportsChat;
  String get displayName => model.isEmpty ? '$name · $type' : '$name · $model';
}

class OfficialImportProgress {
  const OfficialImportProgress({
    required this.stage,
    this.current = 0,
    this.total = 0,
    this.files = 0,
    this.components = 0,
    this.paths = const [],
    this.chunkComponents = 0,
    this.chunkRelations = 0,
    this.findings = const [],
  });

  factory OfficialImportProgress.fromJson(Map<String, dynamic> json) =>
      OfficialImportProgress(
        stage: '${json['stage'] ?? 'starting'}',
        current: (json['current'] as num?)?.toInt() ?? 0,
        total: (json['total'] as num?)?.toInt() ?? 0,
        files: (json['files'] as num?)?.toInt() ?? 0,
        components: (json['components'] as num?)?.toInt() ?? 0,
        paths: (json['paths'] as List? ?? const [])
            .map((item) => '$item')
            .toList(growable: false),
        chunkComponents: (json['chunk_components'] as num?)?.toInt() ?? 0,
        chunkRelations: (json['chunk_relations'] as num?)?.toInt() ?? 0,
        findings: (json['findings'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => OfficialImportFinding.fromJson(item.cast()))
            .toList(growable: false),
      );

  final String stage;
  final int current;
  final int total;
  final int files;
  final int components;
  final List<String> paths;
  final int chunkComponents;
  final int chunkRelations;
  final List<OfficialImportFinding> findings;

  double? get fraction => total > 0 ? current / total : null;
}

class OfficialImportFinding {
  const OfficialImportFinding({
    required this.name,
    required this.resourceType,
    required this.sourcePath,
  });

  factory OfficialImportFinding.fromJson(Map<String, dynamic> json) =>
      OfficialImportFinding(
        name: '${json['name'] ?? ''}',
        resourceType: '${json['resource_type'] ?? ''}',
        sourcePath: '${json['source_path'] ?? ''}',
      );

  final String name;
  final String resourceType;
  final String sourcePath;
}

class OfficialImportEvent {
  const OfficialImportEvent({this.progress, this.draft, this.error});

  final OfficialImportProgress? progress;
  final ImportDraft? draft;
  final String? error;
}

class ImportDraft {
  const ImportDraft({
    required this.id,
    required this.source,
    required this.components,
    required this.errors,
    required this.warnings,
    required this.logs,
    required this.status,
    required this.expired,
  });

  factory ImportDraft.fromJson(Map<String, dynamic> json) {
    final rawSource = (json['source'] as Map?)?.cast<String, dynamic>() ?? json;
    final warnings = <String>[];
    final logs = <String>[];
    for (final item in json['security_warnings'] as List? ?? const []) {
      if (item is Map) {
        final notice = item.cast<String, dynamic>();
        final message = '${notice['message'] ?? ''}'.trim();
        if (message.isEmpty) continue;
        if (notice['level'] == 'log') {
          logs.add(message);
        } else {
          warnings.add(message);
        }
      } else {
        final message = '$item';
        if (_isLegacyImportLog(message)) {
          logs.add(message);
        } else {
          warnings.add(message);
        }
      }
    }
    final selected = (json['selected'] as List? ?? const [])
        .map((item) => '$item')
        .toSet();
    return ImportDraft(
      id: '${json['draft_id'] ?? json['id'] ?? ''}',
      source: OfficialSource.fromJson(rawSource),
      components: (json['components'] as List? ?? const [])
          .whereType<Map>()
          .map((item) {
            final value = item.cast<String, dynamic>();
            if (!value.containsKey('selected') &&
                selected.contains('${value['component_id']}')) {
              value['selected'] = true;
            }
            return ImportComponent.fromJson(value);
          })
          .toList(growable: false),
      errors: (json['errors'] as List? ?? const [])
          .map((item) => '$item')
          .toList(growable: false),
      warnings: List.unmodifiable(warnings),
      logs: List.unmodifiable(logs),
      status: '${json['status'] ?? 'pending'}',
      expired: json['expired'] == true,
    );
  }

  final String id;
  final OfficialSource source;
  final List<ImportComponent> components;
  final List<String> errors;
  final List<String> warnings;
  final List<String> logs;
  final String status;
  final bool expired;

  ImportDraft withComponents(List<ImportComponent> value) => ImportDraft(
    id: id,
    source: source,
    components: value,
    errors: errors,
    warnings: warnings,
    logs: logs,
    status: status,
    expired: expired,
  );
}

bool _isLegacyImportLog(String message) =>
    RegExp(r'^[^:]+: referencia fuera del repositorio \(.+\)$')
        .hasMatch(message.trim());

class ImportDiff {
  const ImportDiff({required this.counts, required this.warnings});

  factory ImportDiff.fromJson(Map<String, dynamic> json) => ImportDiff(
    counts: (json['counts'] as Map? ?? const {}).map(
      (key, value) => MapEntry('$key', (value as num?)?.toInt() ?? 0),
    ),
    warnings: (json['warnings'] as List? ?? const [])
        .map((item) => '$item')
        .toList(growable: false),
  );

  final Map<String, int> counts;
  final List<String> warnings;
}

class OriginInfo {
  const OriginInfo({
    required this.sourceId,
    required this.sourceName,
    required this.repositoryUrl,
    required this.sourcePath,
    required this.commitSha,
  });

  factory OriginInfo.fromJson(Map<String, dynamic> json) => OriginInfo(
    sourceId: '${json['source_id'] ?? ''}',
    sourceName: '${json['source_name'] ?? ''}',
    repositoryUrl: '${json['repository_url'] ?? ''}',
    sourcePath: '${json['source_path'] ?? ''}',
    commitSha: '${json['commit_sha'] ?? ''}',
  );

  final String sourceId;
  final String sourceName;
  final String repositoryUrl;
  final String sourcePath;
  final String commitSha;
}
