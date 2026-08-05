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
    this.tokensIn,
    this.tokensOut,
    this.createdAt,
  });

  final String role;
  final String content;
  final int? tokensIn;
  final int? tokensOut;
  final DateTime? createdAt;

  bool get isUser => role == 'user';

  /// `GET /api/chats/{agent}/{conv}` devuelve tokens como campos planos
  /// `tokens_in`/`tokens_out` (igual que connections/agents) — a diferencia
  /// del evento SSE `done` (`ChatStreamEvent`), que anida `tokens: {in, out}`.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final tokensIn = (json['tokens_in'] as num?)?.toInt();
    final tokensOut = (json['tokens_out'] as num?)?.toInt();
    return ChatMessage(
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      tokensIn: (tokensIn ?? 0) > 0 ? tokensIn : null,
      tokensOut: (tokensOut ?? 0) > 0 ? tokensOut : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  ChatMessage copyWith({
    String? content,
    int? tokensIn,
    int? tokensOut,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      tokensIn: tokensIn ?? this.tokensIn,
      tokensOut: tokensOut ?? this.tokensOut,
      createdAt: createdAt ?? this.createdAt,
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
    this.message,
  });

  final String type;
  final String? token;
  final String? reply;
  final int? tokensIn;
  final int? tokensOut;
  final String? message;

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
      message: json['message']?.toString(),
    );
  }
}
