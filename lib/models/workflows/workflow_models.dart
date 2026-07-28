class WorkflowItem {
  const WorkflowItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String? ?? '';
  String get ownerId => raw['owner_id'] as String? ?? '';
  String get name => raw['name'] as String? ?? '(sin nombre)';
  String get description => raw['description'] as String? ?? '';
  String get scope => raw['scope'] as String? ?? 'private';
  bool get shared => raw['_shared'] == true;

  Map<String, dynamic> get definition {
    final value = raw['definition'];
    if (value is Map<String, dynamic>) return value;
    return const {'nodes': [], 'edges': []};
  }

  List<dynamic> get nodes {
    final value = definition['nodes'];
    if (value is List) return value;
    return const [];
  }

  List<dynamic> get edges {
    final value = definition['edges'];
    if (value is List) return value;
    return const [];
  }

  List<String> get labels {
    final value = raw['labels'];
    if (value is List) {
      return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
    }
    return const ['private'];
  }
}

class WorkflowRunResult {
  const WorkflowRunResult({
    required this.events,
    required this.finalOutput,
    required this.errorMessage,
  });

  final List<Map<String, dynamic>> events;
  final String? finalOutput;
  final String? errorMessage;

  bool get ok => errorMessage == null;
}
