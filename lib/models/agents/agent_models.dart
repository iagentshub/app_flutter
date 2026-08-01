import '../common/resource_item.dart';

class AgentItem extends ResourceItem {
  const AgentItem({required super.raw});

  String get agentType => raw['agent_type'] as String? ?? 'generic';
  String get model => raw['model'] as String? ?? '';
  String get systemPrompt => raw['system_prompt'] as String? ?? '';
  String get connectionId => raw['connection_id'] as String? ?? '';
  bool get useMemory => raw['use_memory'] == true;
  String get memoryFile => raw['memory_file'] as String? ?? '';

  List<String> get skills {
    final value = raw['skills'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }

  List<String> get knowledge {
    final value = raw['knowledge'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }
}
