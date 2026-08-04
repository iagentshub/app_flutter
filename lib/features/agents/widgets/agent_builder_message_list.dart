import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';

/// Transcripción de los constructores por IA de agentes y skills.
///
/// Sin burbujas ni avatares: cada turno es una etiqueta de autor y su texto,
/// separados por espacio en blanco. La jerarquía la da la tipografía.
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
  /// llega, sustituye al indicador de espera del turno en curso.
  final String partialReply;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('agent-builder-messages'),
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
      itemCount: messages.length + (streaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return _Turn(
            message: ChatMessage(role: 'assistant', content: partialReply),
            thinking: thinking && partialReply.isEmpty,
            assistantLabel: assistantLabel,
            userLabel: userLabel,
            thinkingLabel: thinkingLabel,
          );
        }
        return _Turn(
          message: messages[index],
          assistantLabel: assistantLabel,
          userLabel: userLabel,
          thinkingLabel: thinkingLabel,
        );
      },
    );
  }
}

class _Turn extends StatelessWidget {
  const _Turn({
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
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUser ? userLabel : assistantLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isUser ? colors.onSurfaceVariant : colors.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          if (thinking)
            _ThinkingState(label: thinkingLabel)
          else
            _ReadableMessageText(content: message.content),
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
        width: 13,
        height: 13,
        child: CircularProgressIndicator(strokeWidth: 1.6),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      height: 1.6,
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
    if (trimmed.isEmpty) return const SizedBox(height: 10);
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
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(
          heading,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      );
    }
    if (bullet != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•', style: style),
            const SizedBox(width: 8),
            Expanded(child: Text(bullet, style: style)),
          ],
        ),
      );
    }
    return Text(trimmed, style: style);
  }
}
