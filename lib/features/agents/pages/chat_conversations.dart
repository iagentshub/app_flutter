part of 'chat_page.dart';

/// Altas, bajas y carga de conversaciones del chat: listar, crear,
/// seleccionar y borrar, más la carga de sus mensajes.
///
/// Vive aparte para que la página se quede como coordinadora y no vuelva a
/// pasarse del límite que impone `test/feature_architecture_test.dart`.
extension _ChatConversations on _ChatPageState {
  Future<void> _bootstrap() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _refresh(() {
        _error = 'No hay sesión activa';
        _loadingConversations = false;
      });
      return;
    }
    _refresh(() => _loadingConversations = true);
    try {
      final conversations = await _repository.listConversations(
        token,
        widget.agent.id,
      );
      if (!mounted) return;
      if (conversations.isEmpty) {
        final created = await _repository.createConversation(
          token,
          widget.agent.id,
        );
        if (!mounted) return;
        _refresh(() {
          _conversations = [created];
          _conversationId = created.id;
          _loadingConversations = false;
        });
      } else {
        _refresh(() {
          _conversations = conversations;
          _conversationId = conversations.first.id;
          _loadingConversations = false;
        });
      }
      await _loadMessages();
    } on ApiError catch (error) {
      if (!mounted) return;
      _refresh(() {
        _error = error.message;
        _loadingConversations = false;
      });
    } catch (_) {
      if (!mounted) return;
      _refresh(() {
        _error = 'No se pudo cargar el historial de chat';
        _loadingConversations = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    final token = _token;
    final conversationId = _conversationId;
    if (token == null || conversationId == null) return;
    _refresh(() => _loadingMessages = true);
    try {
      final messages = await _repository.getMessages(
        token,
        widget.agent.id,
        conversationId,
      );
      if (!mounted) return;
      _refresh(() {
        _messages = messages;
        _loadingMessages = false;
      });
      scrollToEnd(_scrollController, animate: false);
    } catch (_) {
      if (!mounted) return;
      _refresh(() => _loadingMessages = false);
    }
  }

  Future<void> _newConversation() async {
    final token = _token;
    if (token == null) return;
    try {
      final created = await _repository.createConversation(
        token,
        widget.agent.id,
      );
      if (!mounted) return;
      _refresh(() {
        _conversations = [created, ..._conversations];
        _conversationId = created.id;
        _messages = [];
      });
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo crear la conversación', isError: true);
    }
  }

  Future<void> _selectConversation(String id) async {
    if (id == _conversationId) return;
    _refresh(() {
      _conversationId = id;
      _messages = [];
    });
    await _loadMessages();
  }

  Future<void> _deleteConversation(String id) async {
    final token = _token;
    if (token == null) return;
    try {
      await _repository.deleteConversation(token, widget.agent.id, id);
      if (!mounted) return;
      final remaining = _conversations.where((c) => c.id != id).toList();
      _refresh(() => _conversations = remaining);
      if (_conversationId == id) {
        if (remaining.isEmpty) {
          await _newConversation();
        } else {
          await _selectConversation(remaining.first.id);
        }
      }
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo borrar la conversación', isError: true);
    }
  }
}
