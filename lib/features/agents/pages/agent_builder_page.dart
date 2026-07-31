import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

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
import '../dialogs/agent_form_dialog.dart';
import '../widgets/agent_builder_chat_panel.dart';
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
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _sendSuggestion(String suggestion) {
    _textController.text = suggestion;
    _textController.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
    _send();
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

  Widget _buildModernPage(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(_tx('agents.builder_title', 'Constructor de agentes IA')),
        actions: [
          if (_agentSaved)
            TertiaryButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check),
              label: Text(_tx('agents.builder_done_action', 'Terminar')),
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final setup = _buildSetupPanel(compact: !wide);
          final chat = AgentBuilderChatPanel(
            messages: _messages,
            streaming: _streaming,
            thinking: _thinking,
            enabled: !_loadingConnections && _connectionId != null,
            textController: _textController,
            scrollController: _scrollController,
            onSend: _send,
            onStop: _stop,
            onSuggestion: _sendSuggestion,
            title: _tx('agents.builder_assistant_title', 'Asistente de diseño'),
            subtitle: _tx(
              'agents.builder_assistant_subtitle',
              'Te hará preguntas y preparará un borrador editable',
            ),
            intro: _tx(
              'agents.builder_intro',
              'Describe qué agente quieres crear y para qué lo vas a usar. '
                  'El asistente te hará las preguntas necesarias y propondrá '
                  'un borrador que podrás revisar antes de guardarlo.',
            ),
            inputHint: _tx(
              'agents.builder_input_hint',
              'Describe el agente que quieres crear...',
            ),
            sendTooltip: _tx('agents.builder_send', 'Enviar mensaje'),
            stopTooltip: _tx('agents.builder_stop', 'Detener respuesta'),
            suggestions: [
              _tx(
                'agents.builder_suggestion_support',
                'Un agente para atender clientes',
              ),
              _tx(
                'agents.builder_suggestion_sales',
                'Un asistente para cualificar leads',
              ),
              _tx(
                'agents.builder_suggestion_content',
                'Un experto en crear contenido',
              ),
            ],
            error: _error,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Padding(
                padding: EdgeInsets.all(wide ? 24 : 12),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(width: 300, child: setup),
                          const SizedBox(width: 16),
                          Expanded(child: chat),
                        ],
                      )
                    : Column(
                        children: [
                          setup,
                          const SizedBox(height: 10),
                          Expanded(child: chat),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSetupPanel({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 18),
        child: Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!compact) ...[
              Text(
                _tx('agents.builder_setup_title', 'Configura tu agente'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _tx(
                  'agents.builder_setup_subtitle',
                  'Elige el modelo que te ayudará a diseñarlo.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
            ],
            if (_loadingConnections)
              const LinearProgressIndicator(minHeight: 2)
            else
              DropdownButtonFormField<String>(
                initialValue: _connectionId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _tx('agents.field_connection', 'Conexión LLM'),
                  prefixIcon: const Icon(Icons.hub_outlined),
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
            if (!_loadingConnections && _connections.isEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _tx(
                  'agents.builder_connection_required',
                  'Necesitas una conexión LLM para usar el asistente.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            if (!compact) ...[
              const SizedBox(height: 24),
              _buildStep(
                Icons.chat_bubble_outline,
                '1',
                _tx(
                  'agents.builder_step_describe',
                  'Describe lo que necesitas',
                ),
              ),
              _buildStep(
                Icons.tune,
                '2',
                _tx('agents.builder_step_refine', 'Responde y afina detalles'),
              ),
              _buildStep(
                Icons.fact_check_outlined,
                '3',
                _tx('agents.builder_step_review', 'Revisa el borrador'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStep(IconData icon, String number, String label) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('$number. $label')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _buildModernPage(context);
}
