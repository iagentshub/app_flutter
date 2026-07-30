import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../features/connections/repositories/connections_repository.dart';
import '../../../features/knowledge/repositories/knowledge_repository.dart';
import '../../../features/knowledge/repositories/skills_repository.dart';
import '../../../models/agents/agent_builder_models.dart';
import '../../../models/chat/chat_models.dart';
import '../../../models/connections/connection_models.dart';
import '../repositories/agent_builder_repository.dart';
import '../repositories/agents_repository.dart';
import '../widgets/agent_form_dialog.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';

/// Constructor de agentes por IA: conversación en streaming con el asistente
/// hasta que propone un borrador completo, que se revisa/edita en el mismo
/// formulario que se usa para crear un agente a mano antes de guardarlo.
class AgentBuilderPage extends StatefulWidget {
  const AgentBuilderPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<AgentBuilderPage> createState() => _AgentBuilderPageState();
}

class _AgentBuilderPageState extends State<AgentBuilderPage> {
  late final AgentBuilderRepository _builderRepository;
  late final AgentsRepository _agentsRepository;
  late final ConnectionsRepository _connectionsRepository;
  late final SkillsRepository _skillsRepository;
  late final KnowledgeRepository _knowledgeRepository;
  late final TranslatedTexts _t;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  List<ConnectionItem> _connections = const [];
  bool _loadingConnections = true;
  String? _connectionId;

  List<Map<String, String>> _skillsCatalog = const [];
  List<Map<String, String>> _knowledgeCatalog = const [];

  final List<ChatMessage> _messages = [];
  bool _streaming = false;
  bool _thinking = false;
  String? _error;
  bool _agentSaved = false;
  StreamSubscription<AgentBuilderEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _builderRepository = AgentBuilderRepository(apiClient: widget.apiClient);
    _agentsRepository = AgentsRepository(apiClient: widget.apiClient);
    _connectionsRepository = ConnectionsRepository(apiClient: widget.apiClient);
    _skillsRepository = SkillsRepository(apiClient: widget.apiClient);
    _knowledgeRepository = KnowledgeRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _bootstrap();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _bootstrap() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final results = await Future.wait([
        _connectionsRepository.listConnections(token),
        _skillsRepository.listSkills(token, scope: 'all'),
        _knowledgeRepository.listItems(token),
      ]);
      if (!mounted) return;
      final connections = results[0] as List<ConnectionItem>;
      setState(() {
        _connections = connections;
        _connectionId = connections.isNotEmpty ? connections.first.id : null;
        _loadingConnections = false;
        _skillsCatalog = (results[1] as List)
            .map((s) => {'id': s.id as String, 'name': s.name as String})
            .toList();
        _knowledgeCatalog = (results[2] as List)
            .map((k) => {'id': k.id as String, 'name': k.title as String})
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConnections = false);
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
    final connectionId = _connectionId;
    final text = _textController.text.trim();
    if (token == null || connectionId == null || text.isEmpty || _streaming) {
      if (connectionId == null) {
        _showMessage(
          _tx('agents.builder_no_connection', 'Elige una conexión primero'),
          isError: true,
        );
      }
      return;
    }

    _textController.clear();
    setState(() {
      _error = null;
      _messages.add(ChatMessage(role: 'user', content: text));
      _streaming = true;
      _thinking = true;
    });
    _scrollToEnd();

    final completer = Completer<void>();
    _subscription = _builderRepository
        .streamChat(
          token,
          connectionId: connectionId,
          messages: _messages,
          skills: _skillsCatalog,
          knowledge: _knowledgeCatalog,
        )
        .listen(
          (event) {
            if (event.type == 'progress') {
              _scrollToEnd();
            } else if (event.type == 'error') {
              setState(
                () => _error =
                    event.message ??
                    _tx(
                      'agents.builder_generic_error',
                      'Error del constructor de agentes',
                    ),
              );
            } else if (event.type == 'builder_done') {
              final assistantMessage = event.assistantMessage ?? '';
              setState(() {
                _thinking = false;
                if (assistantMessage.isNotEmpty) {
                  _messages.add(
                    ChatMessage(role: 'assistant', content: assistantMessage),
                  );
                }
              });
              _scrollToEnd();
              if (event.isReady && event.draft != null) {
                _openDraftReview(event.draft!);
              }
            }
          },
          onError: (error) {
            if (!mounted) return;
            setState(
              () => _error = _tx(
                'agents.builder_connection_error',
                'Error de conexión con el constructor de agentes',
              ),
            );
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

  Future<void> _openDraftReview(Map<String, dynamic> draft) async {
    final token = _token;
    if (token == null) return;

    final name = (draft['name'] as String? ?? '').trim();
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final useMemory = draft['use_memory'] == true;

    final initial = <String, dynamic>{
      ...draft,
      'connection_id': _connectionId ?? '',
      'memory_file': useMemory && slug.isNotEmpty ? '$slug.md' : '',
    };

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AgentFormDialog(
        apiClient: widget.apiClient,
        token: token,
        initial: initial,
        tx: _tx,
      ),
    );
    if (payload == null || !mounted) return;
    try {
      await _agentsRepository.saveAgent(token, payload);
      if (!mounted) return;
      setState(() => _agentSaved = true);
      _showMessage(_tx('agents.builder_agent_created', 'Agente creado'));
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('agents.error_generic_save', 'No se pudo guardar el agente'),
        isError: true,
      );
    }
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
        title: Text(_tx('agents.builder_title', 'Constructor de agentes IA')),
        actions: [
          if (_agentSaved)
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check),
              label: Text(_tx('agents.builder_done_action', 'Terminar')),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _loadingConnections
                ? const LinearProgressIndicator(minHeight: 2)
                : DropdownButtonFormField<String>(
                    initialValue: _connectionId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _tx('agents.field_connection', 'Conexión LLM'),
                    ),
                    items: _connections
                        .map(
                          (conn) => DropdownMenuItem<String>(
                            value: conn.id,
                            child: Text(
                              '${conn.name} (${conn.type})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _streaming
                        ? null
                        : (value) => setState(() => _connectionId = value),
                  ),
          ),
          Expanded(child: _buildChatColumn()),
        ],
      ),
    );
  }

  Widget _buildChatColumn() {
    if (_messages.isEmpty && !_streaming) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _tx(
              'agents.builder_intro',
              'Describe qué agente quieres crear y para qué lo vas a usar. '
                  'El asistente te hará las preguntas necesarias y propondrá '
                  'un borrador que podrás revisar antes de guardarlo.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_streaming ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= _messages.length) {
                return _buildBubble(
                  const ChatMessage(role: 'assistant', content: ''),
                  thinking: _thinking,
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
                    decoration: InputDecoration(
                      hintText: _tx(
                        'agents.builder_input_hint',
                        'Describe el agente que quieres crear…',
                      ),
                      border: const OutlineInputBorder(),
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
          child: thinking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(message.content),
        ),
      ),
    );
  }
}
