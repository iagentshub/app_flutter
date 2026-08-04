import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import 'agent_builder_message_list.dart';
import 'builder_draft_card.dart';

/// Superficie de conversación de los constructores por IA de agentes y skills.
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
    required this.intro,
    required this.inputHint,
    required this.sendTooltip,
    required this.stopTooltip,
    required this.suggestions,
    this.assistantLabel = 'Asistente IA',
    this.userLabel = 'Tú',
    this.thinkingLabel = 'Analizando tu solicitud…',
    this.partialReply = '',
    this.draft,
    this.draftTitle = '',
    this.draftActionLabel = '',
    this.onReviewDraft,
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
  final String intro;
  final String inputHint;
  final String sendTooltip;
  final String stopTooltip;
  final List<String> suggestions;
  final String assistantLabel;
  final String userLabel;
  final String thinkingLabel;

  /// Texto visible ya recibido mientras el modelo sigue redactando.
  final String partialReply;

  final Map<String, dynamic>? draft;
  final String draftTitle;
  final String draftActionLabel;
  final VoidCallback? onReviewDraft;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final pendingDraft = draft;
    return Material(
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Expanded(
            child: messages.isEmpty && !streaming
                ? _EmptyConversation(
                    intro: intro,
                    suggestions: suggestions,
                    enabled: enabled,
                    onSuggestion: onSuggestion,
                  )
                : AgentBuilderMessageList(
                    messages: messages,
                    streaming: streaming,
                    thinking: thinking,
                    scrollController: scrollController,
                    assistantLabel: assistantLabel,
                    userLabel: userLabel,
                    thinkingLabel: thinkingLabel,
                    partialReply: partialReply,
                  ),
          ),
          if (pendingDraft != null && onReviewDraft != null)
            BuilderDraftCard(
              draft: pendingDraft,
              title: draftTitle,
              actionLabel: draftActionLabel,
              onReview: onReviewDraft!,
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
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intro,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final suggestion in suggestions)
                          ActionChip(
                            onPressed: enabled
                                ? () => onSuggestion(suggestion)
                                : null,
                            label: Text(suggestion),
                            side: BorderSide(color: colors.outlineVariant),
                          ),
                      ],
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
    final colors = Theme.of(context).colorScheme;
    OutlineInputBorder border(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                style: const TextStyle(height: 1.4),
                decoration: InputDecoration(
                  hintText: hint,
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  border: border(colors.outlineVariant),
                  enabledBorder: border(colors.outlineVariant),
                  focusedBorder: border(colors.primary, width: 1.5),
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
