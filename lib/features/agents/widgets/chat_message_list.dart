import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';
import 'chat_message_bubble.dart';

/// Transcripción de una conversación de chat con un agente, incluida la
/// respuesta en curso mientras se recibe en streaming.
class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    required this.messages,
    required this.streaming,
    required this.thinking,
    required this.streamingReply,
    required this.scrollController,
    required this.onReply,
    required this.copyCodeTooltip,
    required this.replyActionLabel,
    required this.copyActionLabel,
    required this.messageCopiedLabel,
    this.loadingOlder = false,
    super.key,
  });

  final List<ChatMessage> messages;
  final bool streaming;
  final bool thinking;

  /// Texto de la respuesta en curso. Llega como notificador para que los
  /// tokens repinten únicamente la última burbuja, no la lista entera ni la
  /// página que la contiene.
  final ValueListenable<String> streamingReply;
  final ScrollController scrollController;
  final ValueChanged<ChatMessage> onReply;
  final String copyCodeTooltip;
  final String replyActionLabel;
  final String copyActionLabel;
  final String messageCopiedLabel;
  final bool loadingOlder;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (streaming ? 1 : 0) + (loadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (loadingOlder) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          index -= 1;
        }
        if (index < messages.length) return _bubble(messages[index]);
        return ValueListenableBuilder<String>(
          valueListenable: streamingReply,
          builder: (context, reply, _) => _bubble(
            ChatMessage(role: 'assistant', content: reply),
            thinking: thinking && reply.isEmpty,
          ),
        );
      },
    );
  }

  Widget _bubble(ChatMessage message, {bool thinking = false}) {
    return ChatMessageBubble(
      message: message,
      thinking: thinking,
      onReply: onReply,
      copyCodeTooltip: copyCodeTooltip,
      replyActionLabel: replyActionLabel,
      copyActionLabel: copyActionLabel,
      messageCopiedLabel: messageCopiedLabel,
    );
  }
}
