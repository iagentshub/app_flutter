import '../common/resource_item.dart';

class LlmOrchestrationCandidate {
  const LlmOrchestrationCandidate({
    required this.connectionId,
    required this.routingHint,
  });

  final String connectionId;
  final String routingHint;

  factory LlmOrchestrationCandidate.fromJson(Map<String, dynamic> json) =>
      LlmOrchestrationCandidate(
        connectionId: json['connection_id']?.toString() ?? '',
        routingHint: json['routing_hint']?.toString() ?? '',
      );
}

class LlmOrchestrationItem extends ResourceItem {
  const LlmOrchestrationItem({required super.raw});

  String get mode => raw['mode']?.toString() ?? 'stack';
  String get routerConnectionId =>
      raw['router_connection_id']?.toString() ?? '';
  List<LlmOrchestrationCandidate> get candidates {
    final value = raw['candidates'];
    if (value is! List) return const [];
    return value
        .whereType<Map<String, dynamic>>()
        .map(LlmOrchestrationCandidate.fromJson)
        .toList();
  }
}
