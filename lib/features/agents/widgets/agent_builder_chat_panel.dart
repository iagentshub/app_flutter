import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import 'agent_builder_message_list.dart';
import 'builder_draft_card.dart';

/// Superficie de conversación de los constructores por IA de agentes y skills.
///
/// Vive directamente sobre el fondo de la página: sin tarjeta contenedora ni
/// bordes. La única línea es la que separa el compositor de la transcripción.
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
    return Column(
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
        if (error != null && error!.isNotEmpty) _ErrorNotice(message: error!),
        Divider(height: 1, thickness: 1, color: colors.outlineVariant),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            intro,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: colors.onSurfaceVariant,
            ),
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            for (final suggestion in suggestions)
              _SuggestionRow(
                label: suggestion,
                enabled: enabled,
                onPressed: () => onSuggestion(suggestion),
              ),
          ],
        ],
      ),
    );
  }
}

/// Atajo para empezar la conversación. Es una línea de texto pulsable, no un
/// chip: arranca el trabajo sin competir visualmente con la transcripción.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: TertiaryButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          foregroundColor: colors.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: Theme.of(context).textTheme.bodyMedium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.north_east, size: 15, color: colors.onSurfaceVariant),
            const SizedBox(width: 10),
            Flexible(child: Text(label)),
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, size: 16, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.error),
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
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
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.5),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                onSubmitted: enabled ? (_) => onSend() : null,
              ),
            ),
            const SizedBox(width: 4),
            if (streaming)
              AppIconButton(
                tooltip: stopTooltip,
                onPressed: onStop,
                icon: const Icon(Icons.stop_rounded, size: 20),
              )
            else
              AppIconButton(
                tooltip: sendTooltip,
                onPressed: enabled ? onSend : null,
                icon: const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
