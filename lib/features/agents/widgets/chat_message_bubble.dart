import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';

/// Burbuja de un mensaje de chat (usuario o asistente), con indicador de
/// "pensando" mientras llega la respuesta en streaming y el contador de
/// tokens de entrada/salida en las respuestas del asistente.
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    this.thinking = false,
    super.key,
  });

  final ChatMessage message;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (thinking)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(message.content),
              if (!isUser &&
                  (message.tokensIn != null || message.tokensOut != null)) ...[
                const SizedBox(height: 4),
                Text(
                  '↑ ${message.tokensIn ?? 0} ↓ ${message.tokensOut ?? 0} tokens',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
