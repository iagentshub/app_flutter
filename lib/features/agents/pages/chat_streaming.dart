part of 'chat_page.dart';

/// Envío y streaming de la respuesta del agente, más las respuestas "estilo
/// Telegram" a un mensaje concreto (fijar cita, cancelarla, texto citado).
///
/// Vive aparte para que la página se quede como coordinadora y no vuelva a
/// pasarse del límite que impone `test/feature_architecture_test.dart`.
extension _ChatStreaming on _ChatPageState {
  Future<void> _send() async {
    final token = _token;
    final text = _textController.text.trim();
    if (token == null || text.isEmpty || _streaming) return;

    _hideMentionOverlay();
    _textController.clear();
    final attachedKnowledgeIds = _attachedKnowledge.map((k) => k.id).toList();
    final quoted = _replyTo;
    final composedText = quoted == null
        ? text
        : '> ${_replyLabelFor(quoted)}: ${_quoteSnippet(quoted.content)}\n\n$text';
    refresh(() {
      _error = null;
      _routingNotice = null;
      _messages = [
        ..._messages,
        ChatMessage(
          role: 'user',
          content: composedText,
          createdAt: DateTime.now(),
        ),
      ];
      _streaming = true;
      _thinking = true;
      _attachedKnowledge = [];
      _replyTo = null;
    });
    _replyBuffer.clear();
    _streamingReply.value = '';
    // Incondicional a propósito: el usuario acaba de escribir y espera ver su
    // propio mensaje, mire donde mire la vista.
    scrollToEnd(_scrollController, animate: false);

    final history = _messages.where((m) => m.role != 'system').toList();
    final completer = Completer<void>();
    _subscription = _repository
        .streamChat(
          token,
          widget.agent.id,
          messages: history,
          conversationId: _conversationId,
          attachedKnowledgeIds: attachedKnowledgeIds,
        )
        .listen(
          (event) {
            if (event.type == 'token') {
              _replyBuffer.write(event.token ?? '');
              _streamingReply.value = _replyBuffer.toString();
              // El único cambio de estado real del token: ocurre una vez por
              // respuesta, no una vez por token.
              if (_thinking && _streamingReply.value.isNotEmpty) {
                refresh(() => _thinking = false);
              }
              maybeScrollToEnd(_scrollController);
            } else if (event.type == 'done') {
              final reply = event.reply ?? _streamingReply.value;
              refresh(() {
                _thinking = false;
                if (reply.isNotEmpty) {
                  _messages = [
                    ..._messages,
                    ChatMessage(
                      role: 'assistant',
                      content: reply,
                      tokensIn: event.tokensIn,
                      tokensOut: event.tokensOut,
                      createdAt: DateTime.now(),
                    ),
                  ];
                }
              });
              _replyBuffer.clear();
              _streamingReply.value = '';
              maybeScrollToEnd(_scrollController);
            } else if (event.type == 'error') {
              refresh(
                () => _error = event.message ?? 'Error de respuesta del agente',
              );
            } else if (event.type == 'routing_selected' ||
                event.type == 'routing_warning' ||
                event.type == 'routing_failover') {
              refresh(() => _routingNotice = event.message);
            }
          },
          onError: (error) {
            if (!mounted) return;
            refresh(() => _error = 'Error de conexión con el agente');
          },
          onDone: () {
            if (!mounted) return;
            refresh(() {
              _streaming = false;
              _thinking = false;
            });
            if (!completer.isCompleted) completer.complete();
          },
          cancelOnError: true,
        );
    await completer.future;
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    refresh(() {
      _streaming = false;
      _thinking = false;
    });
  }

  void _setReply(ChatMessage message) => refresh(() => _replyTo = message);

  void _cancelReply() => refresh(() => _replyTo = null);

  String _replyLabelFor(ChatMessage message) =>
      message.isUser ? _tx('agents.chat.reply_you', 'Tú') : widget.agent.name;

  /// Aplana y recorta el mensaje citado a una sola línea, como hacen
  /// Telegram/WhatsApp al previsualizar una respuesta.
  String _quoteSnippet(String content) {
    const maxLength = 160;
    final flat = content.replaceAll('\n', ' ').replaceAll('`', '').trim();
    return flat.length > maxLength ? '${flat.substring(0, maxLength)}…' : flat;
  }
}
