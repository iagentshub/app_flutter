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
    super.key,
  });

  final List<ChatMessage> messages;
  final bool streaming;
  final bool thinking;
  final String streamingReply;
  final ScrollController scrollController;
  final ValueChanged<ChatMessage> onReply;
  final String copyCodeTooltip;
  final String replyActionLabel;
  final String copyActionLabel;
  final String messageCopiedLabel;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length + (streaming ? 1 : 0),
      itemBuilder: (context, index) {
        final message = index >= messages.length
            ? ChatMessage(role: 'assistant', content: streamingReply)
            : messages[index];
        return ChatMessageBubble(
          message: message,
          thinking:
              index >= messages.length && thinking && streamingReply.isEmpty,
          onReply: onReply,
          copyCodeTooltip: copyCodeTooltip,
          replyActionLabel: replyActionLabel,
          copyActionLabel: copyActionLabel,
          messageCopiedLabel: messageCopiedLabel,
        );
      },
    );
  }
}
