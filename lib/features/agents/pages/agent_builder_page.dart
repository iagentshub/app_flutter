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
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/skills/skill_models.dart';
import '../repositories/agent_builder_repository.dart';
import '../repositories/agents_repository.dart';
import '../dialogs/agent_form_dialog.dart';
import '../widgets/agent_builder_chat_panel.dart';
import '../widgets/builder_connection_bar.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/scroll_to_end.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';

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

class _AgentBuilderPageState extends State<AgentBuilderPage>
    with StateMessaging {
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
  String _partialReply = '';
  String? _stage;
  Map<String, dynamic>? _pendingDraft;
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
    final failures = <String>[];

    Future<T> load<T>(String label, Future<T> request, T fallback) async {
      try {
        return await request;
      } catch (_) {
        failures.add(label);
        return fallback;
      }
    }

    try {
      final results = await Future.wait([
        load(
          _tx('agents.builder_resource_connections', 'conexiones'),
          _connectionsRepository.listConnections(token),
          const <ConnectionItem>[],
        ),
        load(
          _tx('agents.builder_resource_skills', 'skills'),
          _skillsRepository.listSkills(token, scope: 'all'),
          const <SkillItem>[],
        ),
        load(
          _tx('agents.builder_resource_knowledge', 'conocimiento'),
          _knowledgeRepository.listItems(token),
          const <KnowledgeItem>[],
        ),
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
        if (failures.isNotEmpty) {
          _error =
              '${_tx('agents.builder_load_failed', 'No se pudieron cargar')}: '
              '${failures.join(', ')}';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConnections = false);
    }
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
        showMessage(
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
      _partialReply = '';
      _stage = null;
      _pendingDraft = null;
    });
    scrollToEnd(_scrollController);

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
              final visible = event.assistantMessage ?? '';
              setState(() {
                _stage = event.stage;
                if (visible.isNotEmpty) _partialReply = visible;
              });
              scrollToEnd(_scrollController);
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
                // Cerrar el turno aquí y no en onDone evita que quede una
                // burbuja de espera vacía junto al mensaje ya recibido.
                _streaming = false;
                _thinking = false;
                _partialReply = '';
                _stage = null;
                if (assistantMessage.isNotEmpty) {
                  _messages.add(
                    ChatMessage(role: 'assistant', content: assistantMessage),
                  );
                }
                if (event.isReady && event.draft != null) {
                  _pendingDraft = event.draft;
                }
              });
              scrollToEnd(_scrollController);
            }
          },
          onError: (error) {
            if (!mounted) return;
            unawaited(_handleStreamError(error, connectionId, text));
            if (!completer.isCompleted) completer.complete();
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

  Future<void> _handleStreamError(
    Object error,
    String failedConnectionId,
    String failedText,
  ) async {
    if (!mounted) return;
    final apiError = error is ApiError ? error : null;
    setState(() {
      _streaming = false;
      _thinking = false;
      _partialReply = '';
      _stage = null;
      _error =
          apiError?.message ??
          _tx(
            'agents.builder_connection_error',
            'Error de conexión con el constructor de agentes',
          );
      if (_messages.isNotEmpty &&
          _messages.last.role == 'user' &&
          _messages.last.content == failedText) {
        _messages.removeLast();
      }
      if (_textController.text.isEmpty) {
        _textController.text = failedText;
        _textController.selection = TextSelection.collapsed(
          offset: failedText.length,
        );
      }
    });

    if (apiError?.statusCode != 404) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final refreshed = await _connectionsRepository.listConnections(
        token,
        cache: false,
      );
      if (!mounted) return;
      final available = refreshed
          .where((connection) => connection.id != failedConnectionId)
          .toList();
      setState(() {
        _connections = available;
        final selectedStillExists = available.any(
          (connection) => connection.id == _connectionId,
        );
        if (!selectedStillExists) {
          _connectionId = available.isNotEmpty ? available.first.id : null;
        }
      });
    } catch (_) {
      // Se conserva el error original del backend, que es más útil que un
      // segundo fallo al refrescar el selector.
    }
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
        requireQualityPrompt: true,
      ),
    );
    if (payload == null || !mounted) return;
    try {
      await _agentsRepository.saveAgent(token, payload);
      if (!mounted) return;
      setState(() {
        _agentSaved = true;
        _pendingDraft = null;
      });
      showMessage(_tx('agents.builder_agent_created', 'Agente creado'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
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
      _partialReply = '';
      _stage = null;
    });
  }

  /// Etiqueta de espera correspondiente a la fase informada por el backend.
  String get _thinkingLabel {
    switch (_stage) {
      case 'replying':
        return _tx('agents.builder_stage_replying', 'Redactando respuesta…');
      case 'drafting':
        return _tx('agents.builder_stage_drafting', 'Preparando el borrador…');
      case 'writing_instructions':
        return _tx(
          'agents.builder_stage_writing',
          'Escribiendo las instrucciones del agente…',
        );
      default:
        return _tx(
          'agents.builder_stage_analyzing',
          'Analizando tu solicitud…',
        );
    }
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
              'Define el agente y revisa el borrador antes de crearlo',
            ),
            partialReply: _partialReply,
            thinkingLabel: _thinkingLabel,
            draft: _pendingDraft,
            draftTitle: _tx('agents.builder_draft_ready', 'Borrador propuesto'),
            draftActionLabel: _tx(
              'agents.builder_draft_review',
              'Revisar y crear',
            ),
            onReviewDraft: _pendingDraft == null
                ? null
                : () => _openDraftReview(_pendingDraft!),
            intro: _tx(
              'agents.builder_intro',
              'Describe el objetivo del agente. Incluye sus tareas, límites y '
                  'tono si ya los tienes claros.',
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
              // Ancho de lectura, no de pantalla: el texto es el contenido.
              // 1040 en vez de 760 para no desperdiciar tanto margen en
              // pantallas anchas mientras las líneas siguen siendo legibles.
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: wide ? 24 : 16),
                child: Column(
                  children: [
                    BuilderConnectionBar(
                      loadingConnections: _loadingConnections,
                      streaming: _streaming,
                      connections: _connections,
                      connectionId: _connectionId,
                      onConnectionChanged: (value) =>
                          setState(() => _connectionId = value),
                      tx: _tx,
                    ),
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

  @override
  Widget build(BuildContext context) => _buildModernPage(context);
}
