class ChatConversation {
  const ChatConversation({required this.id, required this.title});

  final String id;
  final String title;

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.tokensIn,
    this.tokensOut,
  });

  final String role;
  final String content;
  final int? tokensIn;
  final int? tokensOut;

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final tokens = json['tokens'];
    int? tokensIn;
    int? tokensOut;
    if (tokens is Map) {
      tokensIn = (tokens['in'] as num?)?.toInt();
      tokensOut = (tokens['out'] as num?)?.toInt();
    }
    return ChatMessage(
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      tokensIn: tokensIn,
      tokensOut: tokensOut,
    );
  }

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  ChatMessage copyWith({String? content, int? tokensIn, int? tokensOut}) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      tokensIn: tokensIn ?? this.tokensIn,
      tokensOut: tokensOut ?? this.tokensOut,
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
