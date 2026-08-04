/// Evento SSE del constructor de agentes por IA (`POST /api/agent-builder/chat`).
class AgentBuilderEvent {
  const AgentBuilderEvent({
    required this.type,
    this.message,
    this.assistantMessage,
    this.stage,
    this.status,
    this.draft,
  });

  final String type;
  final String? message;
  final String? assistantMessage;

  /// Fase declarada por el backend en los eventos `progress`: `analyzing`,
  /// `replying`, `drafting` o `writing_instructions`.
  final String? stage;
  final String? status;
  final Map<String, dynamic>? draft;

  bool get isReady => status == 'ready';

  factory AgentBuilderEvent.fromJson(Map<String, dynamic> json) {
    return AgentBuilderEvent(
      type: json['type']?.toString() ?? '',
      message: json['message']?.toString(),
      assistantMessage: json['assistant_message']?.toString(),
      stage: json['stage']?.toString(),
      status: json['status']?.toString(),
      draft: json['draft'] is Map<String, dynamic>
          ? json['draft'] as Map<String, dynamic>
          : null,
    );
  }
}
