class AgentItem {
  const AgentItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String? ?? '';
  String get name => raw['name'] as String? ?? '(sin nombre)';
  String get scope => raw['scope'] as String? ?? 'private';
  String get agentType => raw['agent_type'] as String? ?? 'generic';
  String get model => raw['model'] as String? ?? '';
  String get description => raw['description'] as String? ?? '';
  String get systemPrompt => raw['system_prompt'] as String? ?? '';
  String get connectionId => raw['connection_id'] as String? ?? '';
  bool get shared => raw['_shared'] == true;

  bool get readOnly => scope == 'public' || shared;

  List<String> get labels {
    final value = raw['labels'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const ['private'];
  }
}
