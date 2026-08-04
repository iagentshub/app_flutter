import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import 'agent_builder_message_list.dart';
import 'builder_draft_card.dart';

/// Superficie de conversación de los constructores por IA de agentes y skills.
///
/// Organiza cabecera, transcripción y compositor en una superficie sobria.
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
    required this.subtitle,
    required this.intro,
    required this.inputHint,
    required this.sendTooltip,
    required this.stopTooltip,
    required this.suggestions,
    this.assistantLabel = 'Asistente IA',
    this.userLabel = 'Tú',
    this.readyLabel = 'Disponible',
    this.workingLabel = 'Generando respuesta',
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
  final String title;
  final String subtitle;
  final String intro;
  final String inputHint;
  final String sendTooltip;
  final String stopTooltip;
  final List<String> suggestions;
  final String assistantLabel;
  final String userLabel;
  final String readyLabel;
  final String workingLabel;
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
      color: colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          _ChatHeader(
            title: title,
            subtitle: subtitle,
            active: enabled,
            busy: streaming,
            readyLabel: readyLabel,
            workingLabel: workingLabel,
          ),
          Divider(height: 1, thickness: 1, color: colors.outlineVariant),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BuilderDraftCard(
                draft: pendingDraft,
                title: draftTitle,
                actionLabel: draftActionLabel,
                onReview: onReviewDraft!,
              ),
            ),
          if (error != null && error!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ErrorNotice(message: error!),
            ),
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
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.busy,
    required this.readyLabel,
    required this.workingLabel,
  });

  final String title;
  final String subtitle;
  final bool active;
  final bool busy;
  final String readyLabel;
  final String workingLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: busy
                  ? colors.primary
                  : active
                  ? const Color(0xFF27845A)
                  : colors.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            busy ? workingLabel : readyLabel,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
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
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
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
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SuggestionRow(
                  label: suggestion,
                  enabled: enabled,
                  onPressed: () => onSuggestion(suggestion),
                ),
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
    return SizedBox(
      width: double.infinity,
      child: SecondaryButton(
        onPressed: enabled ? onPressed : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.onSurface,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: BorderSide(color: colors.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: Theme.of(context).textTheme.bodyMedium,
        ),
        child: Text(label),
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
        padding: const EdgeInsets.all(12),
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
                  filled: true,
                  fillColor: colors.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: colors.primary, width: 1.4),
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
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
                icon: const Icon(Icons.stop_rounded, size: 20),
              )
            else
              AppIconButton.filled(
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
