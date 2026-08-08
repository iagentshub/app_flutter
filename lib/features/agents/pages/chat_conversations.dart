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
      refresh(() {
        _error = 'No hay sesión activa';
        _loadingConversations = false;
      });
      return;
    }
    refresh(() => _loadingConversations = true);
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
        refresh(() {
          _conversations = [created];
          _conversationId = created.id;
          _loadingConversations = false;
        });
      } else {
        refresh(() {
          _conversations = conversations;
          _conversationId = conversations.first.id;
          _loadingConversations = false;
        });
      }
      await _loadMessages();
    } on ApiError catch (error) {
      if (!mounted) return;
      refresh(() {
        _error = error.message;
        _loadingConversations = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _error = 'No se pudo cargar el historial de chat';
        _loadingConversations = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    final token = _token;
    final conversationId = _conversationId;
    if (token == null || conversationId == null) return;
    refresh(() => _loadingMessages = true);
    try {
      final messages = await _repository.getMessages(
        token,
        widget.agent.id,
        conversationId,
      );
      if (!mounted) return;
      refresh(() {
        _messages = messages;
        _loadingMessages = false;
      });
      scrollToEnd(_scrollController, animate: false);
    } catch (_) {
      if (!mounted) return;
      refresh(() => _loadingMessages = false);
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
      refresh(() {
        _conversations = [created, ..._conversations];
        _conversationId = created.id;
        _messages = [];
      });
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx(
          'agents.chat.msg_create_failed',
          'No se pudo crear la conversación',
        ),
        isError: true,
      );
    }
  }

  Future<void> _selectConversation(String id) async {
    if (id == _conversationId) return;
    refresh(() {
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
      refresh(() => _conversations = remaining);
      if (_conversationId == id) {
        if (remaining.isEmpty) {
          await _newConversation();
        } else {
          await _selectConversation(remaining.first.id);
        }
      }
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx(
          'agents.chat.msg_delete_failed',
          'No se pudo borrar la conversación',
        ),
        isError: true,
      );
    }
  }
}
