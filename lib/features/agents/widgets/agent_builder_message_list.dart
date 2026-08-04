import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';

/// Message timeline for the AI-assisted agent and skill builders.
class AgentBuilderMessageList extends StatelessWidget {
  const AgentBuilderMessageList({
    required this.messages,
    required this.streaming,
    required this.thinking,
    required this.scrollController,
    required this.assistantLabel,
    required this.userLabel,
    required this.thinkingLabel,
    this.partialReply = '',
    super.key,
  });

  final List<ChatMessage> messages;
  final bool streaming;
  final bool thinking;
  final ScrollController scrollController;
  final String assistantLabel;
  final String userLabel;
  final String thinkingLabel;

  /// Texto visible ya recibido mientras el modelo sigue redactando. Cuando
  /// llega, sustituye al indicador de espera en la burbuja en curso.
  final String partialReply;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('agent-builder-messages'),
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      itemCount: messages.length + (streaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return _MessageBubble(
            message: ChatMessage(role: 'assistant', content: partialReply),
            thinking: thinking && partialReply.isEmpty,
            assistantLabel: assistantLabel,
            userLabel: userLabel,
            thinkingLabel: thinkingLabel,
          );
        }
        return _MessageBubble(
          message: messages[index],
          assistantLabel: assistantLabel,
          userLabel: userLabel,
          thinkingLabel: thinkingLabel,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.assistantLabel,
    required this.userLabel,
    required this.thinkingLabel,
    this.thinking = false,
  });

  final ChatMessage message;
  final String assistantLabel;
  final String userLabel;
  final String thinkingLabel;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isUser ? 640 : 760),
              child: Column(
                crossAxisAlignment: isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 3,
                      right: 3,
                      bottom: 5,
                    ),
                    child: Text(
                      isUser ? userLabel : assistantLabel,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isUser
                          ? colors.surfaceContainerHigh
                          : colors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 17,
                        vertical: 13,
                      ),
                      child: thinking
                          ? _ThinkingState(label: thinkingLabel)
                          : _ReadableMessageText(content: message.content),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingState extends StatelessWidget {
  const _ThinkingState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}

class _ReadableMessageText extends StatelessWidget {
  const _ReadableMessageText({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final lines = content.trim().split('\n');
    final baseStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      height: 1.55,
      color: Theme.of(context).colorScheme.onSurface,
    );
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines) _ReadableLine(line: line, style: baseStyle),
        ],
      ),
    );
  }
}

class _ReadableLine extends StatelessWidget {
  const _ReadableLine({required this.line, required this.style});

  final String line;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return const SizedBox(height: 8);
    final heading = trimmed.startsWith('### ')
        ? trimmed.substring(4)
        : trimmed.startsWith('## ')
        ? trimmed.substring(3)
        : trimmed.startsWith('# ')
        ? trimmed.substring(2)
        : null;
    final bullet = trimmed.startsWith('- ') || trimmed.startsWith('* ')
        ? trimmed.substring(2)
        : null;

    if (heading != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 5, bottom: 4),
        child: Text(
          heading,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }
    if (bullet != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(bullet, style: style)),
          ],
        ),
      );
    }
    return Text(trimmed, style: style);
  }
}
