import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/chat/chat_models.dart';
import '../repositories/chat_repository.dart';
import '../../../shared/state/session_controller.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    required this.agent,
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final AgentItem agent;
  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRepository _repository;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatConversation> _conversations = const [];
  String? _conversationId;
  List<ChatMessage> _messages = [];
  String _streamingReply = '';
  bool _loadingConversations = true;
  bool _loadingMessages = false;
  bool _streaming = false;
  bool _thinking = false;
  String? _error;
  StreamSubscription<ChatStreamEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository(apiClient: widget.apiClient);
    _bootstrap();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _bootstrap() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loadingConversations = false;
      });
      return;
    }
    setState(() => _loadingConversations = true);
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
        setState(() {
          _conversations = [created];
          _conversationId = created.id;
          _loadingConversations = false;
        });
      } else {
        setState(() {
          _conversations = conversations;
          _conversationId = conversations.first.id;
          _loadingConversations = false;
        });
      }
      await _loadMessages();
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loadingConversations = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el historial de chat';
        _loadingConversations = false;
      });
    }
  }

  Future<void> _loadMessages() async {
    final token = _token;
    final conversationId = _conversationId;
    if (token == null || conversationId == null) return;
    setState(() => _loadingMessages = true);
    try {
      final messages = await _repository.getMessages(
        token,
        widget.agent.id,
        conversationId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loadingMessages = false;
      });
      _scrollToEnd();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMessages = false);
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
      setState(() {
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
    setState(() {
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
      setState(() => _conversations = remaining);
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

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final token = _token;
    final text = _textController.text.trim();
    if (token == null || text.isEmpty || _streaming) return;

    _textController.clear();
    setState(() {
      _error = null;
      _messages = [..._messages, ChatMessage(role: 'user', content: text)];
      _streaming = true;
      _thinking = true;
      _streamingReply = '';
    });
    _scrollToEnd();

    final history = _messages.where((m) => m.role != 'system').toList();
    final completer = Completer<void>();
    _subscription = _repository
        .streamChat(
          token,
          widget.agent.id,
          messages: history,
          conversationId: _conversationId,
        )
        .listen(
          (event) {
            if (event.type == 'token') {
              setState(() {
                _streamingReply += event.token ?? '';
                if (_streamingReply.isNotEmpty) _thinking = false;
              });
              _scrollToEnd();
            } else if (event.type == 'done') {
              final reply = event.reply ?? _streamingReply;
              setState(() {
                _thinking = false;
                if (reply.isNotEmpty) {
                  _messages = [
                    ..._messages,
                    ChatMessage(
                      role: 'assistant',
                      content: reply,
                      tokensIn: event.tokensIn,
                      tokensOut: event.tokensOut,
                    ),
                  ];
                }
                _streamingReply = '';
              });
              _scrollToEnd();
            } else if (event.type == 'error') {
              setState(
                () => _error = event.message ?? 'Error de respuesta del agente',
              );
            }
          },
          onError: (error) {
            if (!mounted) return;
            setState(() => _error = 'Error de conexión con el agente');
          },
          onDone: () {
            if (!mounted) return;
            setState(() {
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
    setState(() {
      _streaming = false;
      _thinking = false;
    });
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.agent.name),
        actions: [
          Builder(
            builder: (context) => LayoutBuilder(
              builder: (context, constraints) {
                if (MediaQuery.of(context).size.width >= 760)
                  return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                );
              },
            ),
          ),
        ],
      ),
      endDrawer: MediaQuery.of(context).size.width >= 760
          ? null
          : Drawer(child: _buildHistoryPanel()),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 760;
          return Row(
            children: [
              if (wide)
                SizedBox(
                  width: 260,
                  child: Material(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    child: _buildHistoryPanel(),
                  ),
                ),
              Expanded(child: _buildChatColumn()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _newConversation,
            icon: const Icon(Icons.add),
            label: const Text('Nueva conversación'),
          ),
        ),
        if (_loadingConversations)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final item = _conversations[index];
                final active = item.id == _conversationId;
                return ListTile(
                  selected: active,
                  dense: true,
                  title: Text(
                    item.title.isEmpty ? 'Conversación' : item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.of(context).maybePop();
                    _selectConversation(item.id);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _deleteConversation(item.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildChatColumn() {
    if (_error != null && _messages.isEmpty && !_loadingMessages) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _bootstrap,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_streaming ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _messages.length) {
                      return _buildBubble(
                        ChatMessage(
                          role: 'assistant',
                          content: _streamingReply,
                        ),
                        thinking: _thinking && _streamingReply.isEmpty,
                      );
                    }
                    return _buildBubble(_messages[index]);
                  },
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un mensaje…',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                if (_streaming)
                  IconButton.filledTonal(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop),
                  )
                else
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(ChatMessage message, {bool thinking = false}) {
    final isUser = message.isUser;
    final bubbleColor = isUser
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Container(
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
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(message.content),
              if (!isUser &&
                  (message.tokensIn != null || message.tokensOut != null)) ...[
                const SizedBox(height: 4),
                Text(
                  '↑ ${message.tokensIn ?? 0} ↓ ${message.tokensOut ?? 0} tokens',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
