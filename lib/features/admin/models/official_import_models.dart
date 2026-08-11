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
    'resources': resources,
  };
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
    this.securityAccepted = false,
    this.securityBlocked = false,
    this.securityReviewRequired = false,
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
        language: '${json['forced_language'] ?? json['language'] ?? ''}',
        securityAccepted: json['security_accepted'] == true,
        securityBlocked: json['security_blocked'] == true,
        securityReviewRequired: json['security_review_required'] == true,
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
  final bool securityAccepted;
  final bool securityBlocked;
  final bool securityReviewRequired;

  String get effectiveType => forcedType ?? type;
}

class ImportDraft {
  const ImportDraft({
    required this.id,
    required this.source,
    required this.components,
    required this.errors,
    required this.warnings,
    required this.status,
    required this.expired,
  });

  factory ImportDraft.fromJson(Map<String, dynamic> json) {
    final rawSource = (json['source'] as Map?)?.cast<String, dynamic>() ?? json;
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
      warnings: (json['security_warnings'] as List? ?? const [])
          .map((item) => '$item')
          .toList(growable: false),
      status: '${json['status'] ?? 'pending'}',
      expired: json['expired'] == true,
    );
  }

  final String id;
  final OfficialSource source;
  final List<ImportComponent> components;
  final List<String> errors;
  final List<String> warnings;
  final String status;
  final bool expired;

  ImportDraft withComponents(List<ImportComponent> value) => ImportDraft(
    id: id,
    source: source,
    components: value,
    errors: errors,
    warnings: warnings,
    status: status,
    expired: expired,
  );
}

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
