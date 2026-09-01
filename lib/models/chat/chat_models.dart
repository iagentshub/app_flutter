class ChatConversation {
  const ChatConversation({
    required this.id,
    required this.title,
    this.tokensIn = 0,
    this.tokensOut = 0,
  });

  final String id;
  final String title;

  /// Suma de tokens de todos los mensajes de esta conversación.
  final int tokensIn;
  final int tokensOut;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      tokensIn: (json['tokens_in'] as num?)?.toInt() ?? 0,
      tokensOut: (json['tokens_out'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.id = '',
    this.tokensIn,
    this.tokensOut,
    this.createdAt,
    this.interrupted = false,
    this.usageEstimated = false,
  });

  final String role;
  final String content;
  final String id;
  final int? tokensIn;
  final int? tokensOut;
  final DateTime? createdAt;
  final bool interrupted;
  final bool usageEstimated;

  bool get isUser => role == 'user';

  /// `GET /api/chats/{agent}/{conv}` devuelve tokens como campos planos
  /// `tokens_in`/`tokens_out` (igual que connections/agents) — a diferencia
  /// del evento SSE `done` (`ChatStreamEvent`), que anida `tokens: {in, out}`.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final tokensIn = (json['tokens_in'] as num?)?.toInt();
    final tokensOut = (json['tokens_out'] as num?)?.toInt();
    return ChatMessage(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      tokensIn: (tokensIn ?? 0) > 0 ? tokensIn : null,
      tokensOut: (tokensOut ?? 0) > 0 ? tokensOut : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      interrupted: json['interrupted'] == true || json['interrupted'] == 1,
      usageEstimated:
          json['usage_estimated'] == true || json['usage_estimated'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  ChatMessage copyWith({
    String? content,
    int? tokensIn,
    int? tokensOut,
    DateTime? createdAt,
    bool? interrupted,
    bool? usageEstimated,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      tokensIn: tokensIn ?? this.tokensIn,
      tokensOut: tokensOut ?? this.tokensOut,
      createdAt: createdAt ?? this.createdAt,
      interrupted: interrupted ?? this.interrupted,
      usageEstimated: usageEstimated ?? this.usageEstimated,
    );
  }
}

class ChatStreamEvent {
  const ChatStreamEvent({
    required this.type,
    this.token,
    this.reply,
    this.tokensIn,
    this.tokensOut,
    this.code,
    this.message,
    this.sources = const [],
  });

  final String type;
  final String? token;
  final String? reply;
  final int? tokensIn;
  final int? tokensOut;
  final String? code;
  final String? message;
  final List<String> sources;

  factory ChatStreamEvent.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'];
    int? tokensIn;
    int? tokensOut;
    if (tokens is Map) {
      tokensIn = (tokens['in'] as num?)?.toInt();
      tokensOut = (tokens['out'] as num?)?.toInt();
    }
    return ChatStreamEvent(
      type: json['type']?.toString() ?? '',
      token: json['token']?.toString(),
      reply: json['reply']?.toString(),
      tokensIn: tokensIn,
      tokensOut: tokensOut,
      code: json['code']?.toString(),
      message: json['message']?.toString(),
      sources: json['sources'] is List
          ? (json['sources'] as List)
                .map((source) => source.toString())
                .toList(growable: false)
          : const [],
    );
  }
}
