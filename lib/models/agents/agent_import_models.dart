enum AgentResourceType {
  skill('skill', 'skills'),
  knowledge('knowledge', 'knowledge'),
  knowledgePack('knowledge_pack', 'knowledge_packs'),
  prompt('prompt', 'prompts'),
  tool('tool', 'tools');

  const AgentResourceType(this.apiValue, this.agentField);

  final String apiValue;
  final String agentField;

  static AgentResourceType? fromApi(String value) => AgentResourceType.values
      .where((item) => item.apiValue == value)
      .firstOrNull;
}

class AgentResourceOption {
  const AgentResourceOption({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle = '',
  });

  final String id;
  final AgentResourceType type;
  final String title;
  final String subtitle;
}

class AgentResourceSelection {
  AgentResourceSelection({
    Set<String> skillIds = const {},
    Set<String> knowledgeIds = const {},
    Set<String> knowledgePackIds = const {},
    Set<String> promptIds = const {},
    Set<String> toolIds = const {},
  }) : skillIds = {...skillIds},
       knowledgeIds = {...knowledgeIds},
       knowledgePackIds = {...knowledgePackIds},
       promptIds = {...promptIds},
       toolIds = {...toolIds};

  final Set<String> skillIds;
  final Set<String> knowledgeIds;
  final Set<String> knowledgePackIds;
  final Set<String> promptIds;
  final Set<String> toolIds;

  int get length => AgentResourceType.values.fold(
    0,
    (count, type) => count + idsFor(type).length,
  );

  Set<String> idsFor(AgentResourceType type) => switch (type) {
    AgentResourceType.skill => skillIds,
    AgentResourceType.knowledgePack => knowledgePackIds,
    AgentResourceType.knowledge => knowledgeIds,
    AgentResourceType.prompt => promptIds,
    AgentResourceType.tool => toolIds,
  };

  Map<String, List<String>> toAgentFields() => {
    for (final type in AgentResourceType.values)
      type.agentField: idsFor(type).toList(),
  };
}

class AgentImportIssue {
  const AgentImportIssue({
    required this.code,
    this.field,
    this.values = const [],
  });

  factory AgentImportIssue.fromJson(Map<String, dynamic> json) =>
      AgentImportIssue(
        code: json['code'] as String? ?? 'unknown',
        field: json['field'] as String?,
        values: (json['values'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(),
      );

  final String code;
  final String? field;
  final List<String> values;
}

class AgentImportDraft {
  const AgentImportDraft({
    required this.name,
    required this.description,
    required this.agentType,
    required this.model,
    required this.systemPrompt,
    required this.temperature,
  });

  factory AgentImportDraft.fromJson(Map<String, dynamic> json) =>
      AgentImportDraft(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        agentType: json['agent_type'] as String? ?? 'generic',
        model: json['model'] as String? ?? '',
        systemPrompt: json['system_prompt'] as String? ?? '',
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      );

  final String name;
  final String description;
  final String agentType;
  final String model;
  final String systemPrompt;
  final double temperature;

  Map<String, dynamic> toFormInitial({
    Map<String, List<String>> linkedResources = const {},
  }) => {
    'name': name,
    'description': description,
    'agent_type': agentType,
    'model': model,
    'system_prompt': systemPrompt,
    'temperature': temperature,
    'scope': 'private',
    'labels': ['private'],
    'skills': linkedResources['skills'] ?? const <String>[],
    'knowledge': linkedResources['knowledge'] ?? const <String>[],
    'knowledge_packs': linkedResources['knowledge_packs'] ?? const <String>[],
    'prompts': linkedResources['prompts'] ?? const <String>[],
    'tools': linkedResources['tools'] ?? const <String>[],
  };
}

class AgentImportPreview {
  const AgentImportPreview({
    required this.filename,
    required this.sourceFormat,
    required this.draft,
    required this.issues,
    required this.references,
    required this.ignoredFields,
  });

  factory AgentImportPreview.fromJson(Map<String, dynamic> json) {
    return AgentImportPreview(
      filename: json['filename'] as String? ?? '',
      sourceFormat: json['source_format'] as String? ?? 'markdown',
      draft: AgentImportDraft.fromJson(
        json['draft'] as Map<String, dynamic>? ?? const {},
      ),
      issues: (json['issues'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AgentImportIssue.fromJson)
          .toList(),
      references: (json['references'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AgentImportReference.fromJson)
          .where((item) => item.type != null)
          .toList(),
      ignoredFields: (json['ignored_fields'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
    );
  }

  final String filename;
  final String sourceFormat;
  final AgentImportDraft draft;
  final List<AgentImportIssue> issues;
  final List<AgentImportReference> references;
  final List<String> ignoredFields;
}

class AgentImportCandidate {
  const AgentImportCandidate({required this.id, required this.name});

  factory AgentImportCandidate.fromJson(Map<String, dynamic> json) =>
      AgentImportCandidate(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
      );

  final String id;
  final String name;
}

class AgentImportReference {
  const AgentImportReference({
    required this.key,
    required this.source,
    required this.status,
    required this.candidates,
    this.type,
    this.selectedId,
    this.localComponentId,
  });

  factory AgentImportReference.fromJson(Map<String, dynamic> json) =>
      AgentImportReference(
        key: json['key']?.toString() ?? '',
        type: AgentResourceType.fromApi(json['kind']?.toString() ?? ''),
        source: json['source']?.toString() ?? '',
        status: json['status']?.toString() ?? 'missing',
        selectedId: json['selected_id']?.toString(),
        localComponentId: json['local_component_id']?.toString(),
        candidates: (json['candidates'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AgentImportCandidate.fromJson)
            .toList(),
      );

  final String key;
  final AgentResourceType? type;
  final String source;
  final String status;
  final String? selectedId;
  final String? localComponentId;
  final List<AgentImportCandidate> candidates;
}

class AgentDirectoryComponent {
  const AgentDirectoryComponent({
    required this.id,
    required this.kind,
    required this.name,
    required this.sourcePath,
    required this.defaultAction,
    required this.candidates,
    required this.references,
    this.selectedExistingId,
    this.securityBlocked = false,
  });

  factory AgentDirectoryComponent.fromJson(Map<String, dynamic> json) =>
      AgentDirectoryComponent(
        id: json['component_id']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        sourcePath: json['source_path']?.toString() ?? '',
        defaultAction: json['default_action']?.toString() ?? 'create',
        selectedExistingId: json['selected_existing_id']?.toString(),
        securityBlocked: json['security_blocked'] == true,
        candidates: (json['existing_candidates'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AgentImportCandidate.fromJson)
            .toList(),
        references: (json['references'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AgentImportReference.fromJson)
            .toList(),
      );

  final String id;
  final String kind;
  final String name;
  final String sourcePath;
  final String defaultAction;
  final String? selectedExistingId;
  final bool securityBlocked;
  final List<AgentImportCandidate> candidates;
  final List<AgentImportReference> references;

  bool get isAgent => kind == 'agent';
}

class AgentDirectoryImportPlan {
  const AgentDirectoryImportPlan({
    required this.components,
    required this.issues,
    required this.ignoredPaths,
  });

  factory AgentDirectoryImportPlan.fromJson(Map<String, dynamic> json) =>
      AgentDirectoryImportPlan(
        components: (json['components'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AgentDirectoryComponent.fromJson)
            .toList(),
        issues: (json['issues'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(AgentImportIssue.fromJson)
            .toList(),
        ignoredPaths: (json['ignored_paths'] as List<dynamic>? ?? const [])
            .map((item) => item.toString())
            .toList(),
      );

  final List<AgentDirectoryComponent> components;
  final List<AgentImportIssue> issues;
  final List<String> ignoredPaths;
}

class AgentDirectoryImportOptions {
  const AgentDirectoryImportOptions({
    required this.selectedAgentIds,
    required this.componentChoices,
    required this.referenceChoices,
  });

  final Set<String> selectedAgentIds;
  final List<Map<String, dynamic>> componentChoices;
  final List<Map<String, dynamic>> referenceChoices;

  Map<String, dynamic> toJson() => {
    'selected_agent_ids': selectedAgentIds.toList(),
    'component_choices': componentChoices,
    'reference_choices': referenceChoices,
  };
}

class AgentDirectoryImportResult {
  const AgentDirectoryImportResult({
    required this.agentCount,
    required this.resourceCount,
  });

  factory AgentDirectoryImportResult.fromJson(Map<String, dynamic> json) =>
      AgentDirectoryImportResult(
        agentCount:
            (json['agent_count'] as num?)?.toInt() ??
            (json['agents'] as List<dynamic>? ?? const []).length,
        resourceCount:
            (json['resource_count'] as num?)?.toInt() ??
            (json['resources'] as List<dynamic>? ?? const []).length,
      );

  final int agentCount;
  final int resourceCount;
}
