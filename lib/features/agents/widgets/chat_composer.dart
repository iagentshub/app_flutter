import 'package:flutter/material.dart';

import '../../../models/knowledge/knowledge_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

/// Composer del chat: campo de texto (con overlay de menciones "@" anclado
/// vía [mentionLink]), chips de conocimiento adjuntado puntualmente y el
/// botón de enviar/detener. Extraído de `ChatPage` para mantenerla dentro del
/// límite de líneas de `feature_architecture_test.dart`.
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje…',
                        border: OutlineInputBorder(),
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
}
