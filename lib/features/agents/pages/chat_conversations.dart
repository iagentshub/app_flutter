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
      final page = await _repository.listConversationPage(
        token,
        widget.agent.id,
      );
      final conversations = page.items;
      if (!mounted) return;
      if (conversations.isEmpty) {
        final created = await _repository.createConversation(
          token,
          widget.agent.id,
        );
        if (!mounted) return;
        refresh(() {
          _conversations = [created];
          _conversationCursor = null;
          _hasMoreConversations = false;
          _conversationId = created.id;
          _loadingConversations = false;
        });
      } else {
        refresh(() {
          _conversations = conversations;
          _conversationCursor = page.nextCursor;
          _hasMoreConversations = page.hasMore;
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

  Future<void> _loadMoreConversations() async {
    final token = _token;
    final cursor = _conversationCursor;
    if (token == null ||
        cursor == null ||
        !_hasMoreConversations ||
        _loadingMoreConversations) {
      return;
    }
    refresh(() => _loadingMoreConversations = true);
    try {
      final page = await _repository.listConversationPage(
        token,
        widget.agent.id,
        cursor: cursor,
      );
      if (!mounted) return;
      final known = _conversations.map((item) => item.id).toSet();
      refresh(() {
        _conversations = [
          ..._conversations,
          ...page.items.where((item) => known.add(item.id)),
        ];
        _conversationCursor = page.nextCursor;
        _hasMoreConversations = page.hasMore;
        _loadingMoreConversations = false;
      });
    } catch (_) {
      if (mounted) refresh(() => _loadingMoreConversations = false);
    }
  }

  Future<void> _loadMessages() async {
    final token = _token;
    final conversationId = _conversationId;
    if (token == null || conversationId == null) return;
    refresh(() => _loadingMessages = true);
    try {
      final page = await _repository.getMessagesPage(
        token,
        widget.agent.id,
        conversationId,
      );
      if (!mounted) return;
      refresh(() {
        _messages = page.items;
        _messageCursor = page.nextCursor;
        _hasOlderMessages = page.hasMore;
        _loadingMessages = false;
      });
      scrollToEnd(_scrollController, animate: false);
    } catch (_) {
      if (!mounted) return;
      refresh(() => _loadingMessages = false);
    }
  }

  Future<void> _loadOlderMessages() async {
    final token = _token;
    final conversationId = _conversationId;
    final cursor = _messageCursor;
    if (token == null ||
        conversationId == null ||
        cursor == null ||
        !_hasOlderMessages ||
        _loadingMessages ||
        _loadingOlderMessages) {
      return;
    }
    refresh(() => _loadingOlderMessages = true);
    final previousExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    try {
      final page = await _repository.getMessagesPage(
        token,
        widget.agent.id,
        conversationId,
        cursor: cursor,
      );
      if (!mounted || conversationId != _conversationId) return;
      final known = _messages.map((item) => item.id).toSet();
      refresh(() {
        _messages = [
          ...page.items.where((item) => known.add(item.id)),
          ..._messages,
        ];
        _messageCursor = page.nextCursor;
        _hasOlderMessages = page.hasMore;
        _loadingOlderMessages = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final delta =
            _scrollController.position.maxScrollExtent - previousExtent;
        _scrollController.jumpTo(_scrollController.offset + delta);
      });
    } catch (_) {
      if (mounted) refresh(() => _loadingOlderMessages = false);
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
        _messageCursor = null;
        _hasOlderMessages = false;
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
      _messageCursor = null;
      _hasOlderMessages = false;
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
