import 'package:flutter/material.dart';

import '../../../models/chat/chat_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

/// Composer del chat: campo de texto (con overlay de menciones "@" anclado
/// vía [mentionLink]), chips de conocimiento adjuntado puntualmente, la
/// vista previa del mensaje al que se está respondiendo (estilo
/// Telegram/WhatsApp) y el botón de enviar/detener. Extraído de `ChatPage`
/// para mantenerla dentro del límite de líneas de
/// `feature_architecture_test.dart`.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.textController,
    required this.mentionLink,
    required this.attachedKnowledge,
    required this.onRemoveKnowledge,
    required this.streaming,
    required this.onSend,
    required this.onStop,
    required this.sendTooltip,
    required this.stopTooltip,
    required this.composerHint,
    this.replyTo,
    this.replyToLabel,
    this.onCancelReply,
    this.cancelReplyTooltip,
    super.key,
  });

  final TextEditingController textController;
  final LayerLink mentionLink;
  final List<KnowledgeItem> attachedKnowledge;
  final ValueChanged<String> onRemoveKnowledge;
  final bool streaming;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final String sendTooltip;
  final String stopTooltip;
  final String composerHint;

  /// Mensaje citado al responder, y el nombre de quien lo escribió
  /// ("Tú" o el nombre del agente). `null` cuando no hay respuesta activa.
  final ChatMessage? replyTo;
  final String? replyToLabel;
  final VoidCallback? onCancelReply;
  final String? cancelReplyTooltip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (replyTo != null) _buildReplyPreview(context),
            if (attachedKnowledge.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: attachedKnowledge
                      .map(
                        (item) => InputChip(
                          avatar: const Icon(
                            Icons.description_outlined,
                            size: 16,
                          ),
                          label: Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onDeleted: () => onRemoveKnowledge(item.id),
                        ),
                      )
                      .toList(),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: CompositedTransformTarget(
                    link: mentionLink,
                    child: TextField(
                      controller: textController,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: composerHint,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (streaming)
                  AppIconButton.filledTonal(
                    onPressed: onStop,
                    tooltip: stopTooltip,
                    icon: const Icon(Icons.stop),
                  )
                else
                  AppIconButton.filled(
                    onPressed: onSend,
                    tooltip: sendTooltip,
                    icon: const Icon(Icons.send),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final quoted = replyTo!.content.replaceAll('\n', ' ').trim();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyToLabel ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  quoted,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          ActionIconButton(
            icon: Icons.close,
            tooltip: cancelReplyTooltip ?? '',
            onPressed: onCancelReply,
          ),
        ],
      ),
    );
  }
}
