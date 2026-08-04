import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import 'agent_builder_message_list.dart';

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
    required this.subtitle,
    required this.intro,
    required this.inputHint,
    required this.sendTooltip,
    required this.stopTooltip,
    required this.suggestions,
    this.assistantLabel = 'Asistente IA',
    this.userLabel = 'Tú',
    this.readyLabel = 'Disponible',
    this.workingLabel = 'Diseñando',
    this.thinkingLabel = 'Analizando tu solicitud…',
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
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLowest,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
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
          Divider(height: 1, color: colors.outlineVariant),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.primary, colors.tertiary],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  size: 21,
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
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
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: busy
                      ? colors.tertiaryContainer
                      : active
                      ? const Color(0xFFE7F7EF)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: busy
                            ? colors.tertiary
                            : active
                            ? const Color(0xFF168A5B)
                            : colors.outline,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 7),
                      Text(
                        busy ? workingLabel : readyLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: busy
                              ? colors.onTertiaryContainer
                              : active
                              ? const Color(0xFF126B49)
                              : colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      size: 28,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    intro,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      height: 1.45,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (suggestions.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: suggestions
                          .asMap()
                          .entries
                          .map(
                            (entry) => ActionChip(
                              onPressed: enabled
                                  ? () => onSuggestion(entry.value)
                                  : null,
                              avatar: Icon(
                                [
                                  Icons.support_agent_rounded,
                                  Icons.trending_up_rounded,
                                  Icons.campaign_rounded,
                                ][entry.key % 3],
                                size: 18,
                              ),
                              label: Text(entry.value),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              side: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                              ),
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
                  fillColor: Theme.of(context).colorScheme.surface,
                  prefixIcon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 19,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
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
