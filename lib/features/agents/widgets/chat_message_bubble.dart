import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../models/chat/chat_models.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import 'chat_markdown_body.dart';

String _fmtTime(DateTime dt) {
  final local = dt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

/// Burbuja de un mensaje de chat (usuario o asistente), con indicador de
/// "pensando" mientras llega la respuesta en streaming, el contador de
/// tokens de entrada/salida en las respuestas del asistente, y un menú de
/// mantener presionado (estilo Telegram/WhatsApp) para copiar o responder al
/// mensaje. El contenido se renderiza con [ChatMarkdownBody], que muestra
/// los bloques de código con un botón "copiar todo".
class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    required this.message,
    required this.onReply,
    required this.copyCodeTooltip,
    required this.replyActionLabel,
    required this.copyActionLabel,
    required this.messageCopiedLabel,
    required this.interruptedLabel,
    required this.estimatedUsageLabel,
    required this.tokensInputLabel,
    required this.tokensOutputLabel,
    required this.tokensUnitLabel,
    this.thinking = false,
    super.key,
  });

  final ChatMessage message;
  final bool thinking;
  final ValueChanged<ChatMessage> onReply;
  final String copyCodeTooltip;
  final String replyActionLabel;
  final String copyActionLabel;
  final String messageCopiedLabel;
  final String interruptedLabel;
  final String estimatedUsageLabel;
  final String tokensInputLabel;
  final String tokensOutputLabel;
  final String tokensUnitLabel;

  bool get _actionsEnabled => !thinking && message.content.trim().isNotEmpty;

  Future<void> _showActions(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: Text(replyActionLabel),
              onTap: () => Navigator.of(sheetContext).pop('reply'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: Text(copyActionLabel),
              onTap: () => Navigator.of(sheetContext).pop('copy'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'reply') {
      onReply(message);
    } else if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: message.content));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(messageCopiedLabel)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final hasMetadata =
        !thinking &&
        (message.createdAt != null ||
            (!isUser &&
                (message.tokensIn != null || message.tokensOut != null)));

    final bubble = Container(
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
            const SizedBox(width: 18, height: 18, child: IAgentsLoadingMark())
          else
            ChatMarkdownBody(
              text: message.content,
              copyCodeTooltip: copyCodeTooltip,
            ),
          if (!thinking && !isUser && message.interrupted) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.stop_circle_outlined, size: 14),
                const SizedBox(width: 4),
                Text(
                  interruptedLabel,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ],
          if (hasMetadata) _buildMetadata(context, isUser),
        ],
      ),
    );

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: _actionsEnabled
            ? Material(
                color: FncColors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onLongPress: () => _showActions(context),
                  child: bubble,
                ),
              )
            : bubble,
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, bool isUser) {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant, height: 1.2);

    return Container(
      key: const Key('chat-message-metadata'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7)),
        ),
      ),
      child: Wrap(
        alignment: isUser ? WrapAlignment.end : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 6,
        children: [
          if (!isUser &&
              (message.tokensIn != null || message.tokensOut != null))
            _MetadataItem(
              key: const Key('chat-message-token-usage'),
              icon: Icons.data_usage_outlined,
              text:
                  '$tokensInputLabel ${message.tokensIn ?? 0} · '
                  '$tokensOutputLabel ${message.tokensOut ?? 0} '
                  '$tokensUnitLabel',
              style: style,
            ),
          if (!isUser && message.usageEstimated)
            _MetadataItem(
              icon: Icons.info_outline,
              text: estimatedUsageLabel,
              style: style,
            ),
          if (message.createdAt != null)
            _MetadataItem(
              key: const Key('chat-message-time'),
              icon: Icons.schedule,
              text: _fmtTime(message.createdAt!),
              style: style,
            ),
        ],
      ),
    );
  }
}

class _MetadataItem extends StatelessWidget {
  const _MetadataItem({
    required this.icon,
    required this.text,
    required this.style,
    super.key,
  });

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final color = style?.color;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(text, style: style)),
      ],
    );
  }
}
