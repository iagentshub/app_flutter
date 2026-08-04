part of '../pages/chat_page.dart';

/// Autocompletado visual de menciones `@alias` en el composer del chat:
/// solo sugiere los prompts vinculados al agente actual (`widget.agent.prompts`).
/// Nunca sustituye el texto por el contenido del prompt — el token `@alias`
/// se manda literal y el backend lo resuelve de forma transparente al chatear.
/// Separado en su propio fichero para no hacer crecer sin límite
/// `chat_page.dart` (ver `feature_architecture_test.dart`).
extension _ChatMentionOverlay on _ChatPageState {
  Future<void> _loadAgentPrompts() async {
    final token = _token;
    final promptIds = widget.agent.prompts.toSet();
    if (token == null || token.isEmpty || promptIds.isEmpty) return;
    try {
      final all = await _promptsRepository.listPrompts(token, scope: 'all');
      if (!mounted) return;
      _refresh(() {
        _agentPrompts = all.where((p) => promptIds.contains(p.id)).toList();
      });
    } catch (_) {
      // El autocompletado de @alias es una ayuda visual, no crítica: si
      // falla la carga, el usuario aún puede escribir @alias a mano.
    }
  }

  /// Texto parcial tras la `@` más cercana hacia atrás desde el cursor, sin
  /// espacios/saltos de línea entre medias. `null` si no hay mención activa.
  String? _activeMentionQuery() {
    final text = _textController.text;
    final selection = _textController.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;
    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) return null;
    var i = cursor - 1;
    while (i >= 0) {
      final char = text[i];
      if (char == '@') return text.substring(i + 1, cursor);
      if (char == ' ' || char == '\n' || char == '\t') return null;
      i--;
    }
    return null;
  }

  void _onComposerTextChanged() {
    if (_agentPrompts.isEmpty) return;
    final query = _activeMentionQuery();
    if (query == null) {
      _hideMentionOverlay();
      return;
    }
    final lower = query.toLowerCase();
    final matches = _agentPrompts
        .where((p) => p.alias.toLowerCase().startsWith(lower))
        .toList();
    if (matches.isEmpty) {
      _hideMentionOverlay();
      return;
    }
    _mentionMatches = matches;
    _showOrUpdateMentionOverlay();
  }

  void _showOrUpdateMentionOverlay() {
    if (_mentionOverlay == null) {
      _mentionOverlay = OverlayEntry(builder: (context) => _buildMentionOverlay());
      Overlay.of(context).insert(_mentionOverlay!);
    } else {
      _mentionOverlay!.markNeedsBuild();
    }
  }

  void _hideMentionOverlay() {
    final overlay = _mentionOverlay;
    if (overlay == null) return;
    _mentionOverlay = null;
    overlay.remove();
  }

  Widget _buildMentionOverlay() {
    return Positioned(
      width: 280,
      child: CompositedTransformFollower(
        link: _mentionLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topLeft,
        followerAnchor: Alignment.bottomLeft,
        offset: const Offset(0, -8),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _mentionMatches.length,
              itemBuilder: (context, index) {
                final prompt = _mentionMatches[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.bolt_outlined, size: 18),
                  title: Text('@${prompt.alias}'),
                  subtitle: Text(
                    prompt.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _selectMention(prompt),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Sustituye solo el token parcial `@ali` por el alias completo `@alias `
  /// (con espacio final) en el texto — nunca inserta el contenido del
  /// prompt, eso lo resuelve el backend de forma transparente al enviar.
  void _selectMention(PromptItem prompt) {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    if (cursor < 0) {
      _hideMentionOverlay();
      return;
    }
    var start = cursor - 1;
    while (start >= 0 && text[start] != '@') {
      start--;
    }
    if (start < 0) {
      _hideMentionOverlay();
      return;
    }
    final replacement = '@${prompt.alias} ';
    final newText = text.replaceRange(start, cursor, replacement);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _hideMentionOverlay();
  }
}
