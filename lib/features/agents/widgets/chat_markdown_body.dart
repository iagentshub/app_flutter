import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';

/// Renderiza el contenido de un mensaje de chat reconociendo bloques de
/// código ` ```lang `, código inline `` `code` `` y citas `> texto` (usadas
/// para el "responder a" estilo Telegram/WhatsApp). El resto se muestra como
/// texto plano seleccionable.
class ChatMarkdownBody extends StatelessWidget {
  const ChatMarkdownBody({
    required this.text,
    required this.copyCodeTooltip,
    this.style,
    super.key,
  });

  final String text;
  final String copyCodeTooltip;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    final children = <Widget>[];
    for (final block in blocks) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 6));
      children.add(
        block.isCode
            ? _CodeBlock(
                code: block.text,
                lang: block.lang,
                copyTooltip: copyCodeTooltip,
              )
            : _TextSegment(text: block.text, style: style),
      );
    }
    if (children.isEmpty) return Text(text, style: style);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _ContentBlock {
  const _ContentBlock.text(this.text) : isCode = false, lang = null;
  const _ContentBlock.code(this.text, this.lang) : isCode = true;

  final bool isCode;
  final String text;
  final String? lang;
}

List<_ContentBlock> _parseBlocks(String content) {
  final lines = content.split('\n');
  final blocks = <_ContentBlock>[];
  final buffer = StringBuffer();
  var i = 0;

  void flushText() {
    final text = buffer.toString();
    if (text.trim().isNotEmpty) blocks.add(_ContentBlock.text(text));
    buffer.clear();
  }

  final fenceOpen = RegExp(r'^```(\w*)\s*$');
  while (i < lines.length) {
    final fenceMatch = fenceOpen.firstMatch(lines[i].trim());
    if (fenceMatch != null) {
      flushText();
      final lang = fenceMatch.group(1) ?? '';
      i++;
      final codeLines = <String>[];
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.add(lines[i]);
        i++;
      }
      if (i < lines.length) i++; // consume closing fence
      blocks.add(
        _ContentBlock.code(codeLines.join('\n'), lang.isEmpty ? null : lang),
      );
      continue;
    }
    buffer.writeln(lines[i]);
    i++;
  }
  flushText();
  return blocks;
}

/// Un tramo de texto normal, separando líneas de cita (`> `) — mostradas
/// como bloque referenciado — de párrafos normales con código inline.
class _TextSegment extends StatelessWidget {
  const _TextSegment({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    final normal = <String>[];

    void flushNormal() {
      final joined = normal.join('\n').trim();
      if (joined.isNotEmpty) {
        widgets.add(_InlineText(text: joined, style: style));
      }
      normal.clear();
    }

    var i = 0;
    while (i < lines.length) {
      final line = lines[i];
      if (line.startsWith('> ') || line == '>') {
        flushNormal();
        final quote = <String>[];
        while (i < lines.length &&
            (lines[i].startsWith('> ') || lines[i] == '>')) {
          quote.add(lines[i].startsWith('> ') ? lines[i].substring(2) : '');
          i++;
        }
        widgets.add(_QuoteBlock(text: quote.join('\n')));
      } else {
        normal.add(line);
        i++;
      }
    }
    flushNormal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}

/// Texto con soporte para código inline `` `code` ``.
///
/// Usa `Text.rich` (no seleccionable) a propósito: el mensaje completo vive
/// dentro del `InkWell` de mantener-presionado de [ChatMessageBubble], y un
/// `SelectableText` captura el gesto de long-press para selección antes de
/// que llegue al menú de responder/copiar.
class _InlineText extends StatelessWidget {
  const _InlineText({required this.text, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    final pattern = RegExp(r'`([^`\n]+)`');
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(TextSpan(text: text.substring(last, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontFamily: FncFonts.monospace,
            fontSize: (baseStyle.fontSize ?? 14) - 1,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      );
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}

/// Bloque de cita usado al "responder" a un mensaje anterior, con una barra
/// vertical de acento como en Telegram/WhatsApp.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Text(
        text,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color.withValues(alpha: 0.85),
          fontSize: FncFonts.size12_5,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Bloque de código con cabecera (lenguaje + botón "copiar todo").
class _CodeBlock extends StatefulWidget {
  const _CodeBlock({required this.code, required this.copyTooltip, this.lang});

  final String code;
  final String? lang;
  final String copyTooltip;

  @override
  State<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends State<_CodeBlock> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 10, right: 4),
            color: scheme.surfaceContainerHigh,
            child: Row(
              children: [
                if ((widget.lang ?? '').isNotEmpty)
                  Expanded(
                    child: Text(
                      widget.lang!,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  )
                else
                  const Spacer(),
                ActionIconButton(
                  icon: _copied ? Icons.check : Icons.copy_all_outlined,
                  tooltip: widget.copyTooltip,
                  onPressed: _copy,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SelectableText(
                widget.code,
                style: const TextStyle(
                  fontFamily: FncFonts.monospace,
                  fontSize: FncFonts.size13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
