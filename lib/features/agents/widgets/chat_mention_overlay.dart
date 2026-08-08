part of '../pages/chat_page.dart';

/// Autocompletado visual de menciones `@` en el composer del chat: sugiere
/// todos los prompts y conocimientos accesibles del usuario (no solo los
/// vinculados al agente actual).
/// - Seleccionar un prompt inserta el token `@alias` literal — nunca sustituye
///   el texto por su contenido, el backend lo resuelve de forma transparente
///   al chatear.
/// - Seleccionar un conocimiento no inserta texto: se adjunta como "chip"
///   visible sobre el composer y se manda aparte al enviar (contexto puntual
///   para ese mensaje, no una vinculación permanente al agente).
/// Separado en su propio fichero para no hacer crecer sin límite
/// `chat_page.dart` (ver `feature_architecture_test.dart`).
extension _ChatMentionOverlay on _ChatPageState {
  Future<void> _loadMentionSources() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final results = await Future.wait([
        _promptsRepository.listPrompts(token, scope: 'all'),
        _knowledgeRepository.listItems(token),
      ]);
      if (!mounted) return;
      refresh(() {
        _allPrompts = results[0] as List<PromptItem>;
        _allKnowledge = results[1] as List<KnowledgeItem>;
      });
    } catch (_) {
      // El autocompletado de "@" es una ayuda visual, no crítica: si falla la
      // carga, el usuario aún puede escribir @alias a mano.
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
    if (_allPrompts.isEmpty && _allKnowledge.isEmpty) return;
    final query = _activeMentionQuery();
    if (query == null) {
      _hideMentionOverlay();
      return;
    }
    final lower = query.toLowerCase();
    final promptMatches = _allPrompts
        .where((p) => p.alias.toLowerCase().startsWith(lower))
        .toList();
    final knowledgeMatches = _allKnowledge
        .where((k) => k.name.toLowerCase().contains(lower))
        .toList();
    if (promptMatches.isEmpty && knowledgeMatches.isEmpty) {
      _hideMentionOverlay();
      return;
    }
    _promptMentionMatches = promptMatches;
    _knowledgeMentionMatches = knowledgeMatches;
    _showOrUpdateMentionOverlay();
  }

  void _showOrUpdateMentionOverlay() {
    if (_mentionOverlay == null) {
      _mentionOverlay = OverlayEntry(
        builder: (context) => _buildMentionOverlay(),
      );
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
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                if (_promptMentionMatches.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Text(
                      'Prompts',
                      style: TextStyle(
                        fontSize: FncFonts.size11,
                        color: FncColors.materialGrey,
                      ),
                    ),
                  ),
                  for (final prompt in _promptMentionMatches)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.bolt_outlined, size: 18),
                      title: Text('@${prompt.alias}'),
                      subtitle: Text(
                        prompt.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectPromptMention(prompt),
                    ),
                ],
                if (_knowledgeMentionMatches.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, 2),
                    child: Text(
                      'Conocimiento',
                      style: TextStyle(
                        fontSize: FncFonts.size11,
                        color: FncColors.materialGrey,
                      ),
                    ),
                  ),
                  for (final item in _knowledgeMentionMatches)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.description_outlined, size: 18),
                      title: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _selectKnowledgeMention(item),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Elimina el token parcial `@quer` tecleado tras la última `@`, dejando el
  /// texto listo para insertar un reemplazo o para borrarlo sin más.
  ({int start, int cursor})? _mentionTokenRange() {
    final text = _textController.text;
    final cursor = _textController.selection.baseOffset;
    if (cursor < 0) return null;
    var start = cursor - 1;
    while (start >= 0 && text[start] != '@') {
      start--;
    }
    if (start < 0) return null;
    return (start: start, cursor: cursor);
  }

  /// Sustituye solo el token parcial `@ali` por el alias completo `@alias `
  /// (con espacio final) en el texto — nunca inserta el contenido del
  /// prompt, eso lo resuelve el backend de forma transparente al enviar.
  void _selectPromptMention(PromptItem prompt) {
    final range = _mentionTokenRange();
    if (range == null) {
      _hideMentionOverlay();
      return;
    }
    final text = _textController.text;
    final replacement = '@${prompt.alias} ';
    final newText = text.replaceRange(range.start, range.cursor, replacement);
    _textController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: range.start + replacement.length,
      ),
    );
    _hideMentionOverlay();
  }

  /// Borra el token parcial `@quer` tecleado (no es texto parseable por el
  /// backend) y adjunta el conocimiento como contexto puntual para el
  /// próximo envío, mostrado como chip sobre el composer.
  void _selectKnowledgeMention(KnowledgeItem item) {
    final range = _mentionTokenRange();
    if (range != null) {
      final text = _textController.text;
      final newText = text.replaceRange(range.start, range.cursor, '');
      _textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: range.start),
      );
    }
    _hideMentionOverlay();
    if (_attachedKnowledge.any((k) => k.id == item.id)) return;
    refresh(() {
      _attachedKnowledge = [..._attachedKnowledge, item];
    });
  }
}
