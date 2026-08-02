import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

/// Responsive conversation surface used by the AI agent builder.
class AgentBuilderChatPanel extends StatelessWidget {
  const AgentBuilderChatPanel({
    required this.messages,
    required this.streaming,
    required this.thinking,
    required this.enabled,
    required this.textController,
    required this.scrollController,
    required this.onSend,
    required this.onStop,
    required this.onSuggestion,
    required this.title,
    required this.intro,
    required this.inputHint,
    required this.sendTooltip,
    required this.stopTooltip,
    required this.suggestions,
    this.error,
    super.key,
  });

  final List<ChatMessage> messages;
  final bool streaming;
  final bool thinking;
  final bool enabled;
  final TextEditingController textController;
  final ScrollController scrollController;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final ValueChanged<String> onSuggestion;
  final String title;
  final String intro;
  final String inputHint;
  final String sendTooltip;
  final String stopTooltip;
  final List<String> suggestions;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          _ChatHeader(title: title),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(
            child: messages.isEmpty && !streaming
                ? _EmptyConversation(
                    intro: intro,
                    suggestions: suggestions,
                    enabled: enabled,
                    onSuggestion: onSuggestion,
                  )
                : _MessageList(
                    messages: messages,
                    streaming: streaming,
                    thinking: thinking,
                    scrollController: scrollController,
                  ),
          ),
          if (error != null && error!.isNotEmpty) _ErrorBanner(message: error!),
          Divider(height: 1, color: colors.outlineVariant),
          _Composer(
            controller: textController,
            enabled: enabled && !streaming,
            streaming: streaming,
            hint: inputHint,
            sendTooltip: sendTooltip,
            stopTooltip: stopTooltip,
            onSend: onSend,
            onStop: onStop,
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({
    required this.intro,
    required this.suggestions,
    required this.enabled,
    required this.onSuggestion,
  });

  final String intro;
  final List<String> suggestions;
  final bool enabled;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(intro, style: Theme.of(context).textTheme.bodyMedium),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: suggestions
                          .map(
                            (suggestion) => ActionChip(
                              onPressed: enabled
                                  ? () => onSuggestion(suggestion)
                                  : null,
                              label: Text(suggestion),
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.streaming,
    required this.thinking,
    required this.scrollController,
  });

  final List<ChatMessage> messages;
  final bool streaming;
  final bool thinking;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey('agent-builder-messages'),
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: messages.length + (streaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return _MessageBubble(
            message: const ChatMessage(role: 'assistant', content: ''),
            thinking: thinking,
          );
        }
        return _MessageBubble(message: messages[index]);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, this.thinking = false});

  final ChatMessage message;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isUser ? 680 : double.infinity),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isUser
                  ? colors.surfaceContainerHighest
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isUser ? 14 : 0,
                vertical: isUser ? 10 : 4,
              ),
              child: thinking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : SelectableText(
                      message.content,
                      style: const TextStyle(height: 1.5),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: colors.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.streaming,
    required this.hint,
    required this.sendTooltip,
    required this.stopTooltip,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool streaming;
  final String hint;
  final String sendTooltip;
  final String stopTooltip;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('agent-builder-composer'),
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 6,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hint,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onSubmitted: enabled ? (_) => onSend() : null,
              ),
            ),
            const SizedBox(width: 8),
            if (streaming)
              AppIconButton.filledTonal(
                tooltip: stopTooltip,
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded),
              )
            else
              AppIconButton.filled(
                tooltip: sendTooltip,
                onPressed: enabled ? onSend : null,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
          ],
        ),
      ),
    );
  }
}
