import '../common/resource_item.dart';

class WorkflowItem extends ResourceItem {
  const WorkflowItem({required super.raw});

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

  String get llmOrchestrationConnectionId =>
      definition['llm_orchestration_connection_id']?.toString() ?? '';

  @override
  List<String> get labels {
    final value = raw['labels'];
    if (value is List) {
      return value
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const ['private'];
  }
}
