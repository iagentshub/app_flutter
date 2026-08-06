import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../features/agents/widgets/agent_builder_chat_panel.dart';
import '../../../features/agents/widgets/builder_connection_bar.dart';
import '../../../features/connections/repositories/connections_repository.dart';
import '../../../models/agents/agent_builder_models.dart';
import '../../../models/chat/chat_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/scroll_to_end.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../repositories/skill_builder_repository.dart';

class SkillBuilderPage extends StatefulWidget {
  const SkillBuilderPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    required this.onReviewDraft,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;
  final Future<bool> Function(Map<String, dynamic> draft) onReviewDraft;

  @override
  State<SkillBuilderPage> createState() => _SkillBuilderPageState();
}

class _SkillBuilderPageState extends State<SkillBuilderPage> {
  late final SkillBuilderRepository _builderRepository;
  late final ConnectionsRepository _connectionsRepository;
  late final TranslatedTexts _t;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  List<ConnectionItem> _connections = const [];
  String? _connectionId;
  bool _loadingConnections = true;
  bool _streaming = false;
  bool _thinking = false;
  bool _skillSaved = false;
  String _partialReply = '';
  String? _stage;
  Map<String, dynamic>? _pendingDraft;
  String? _error;
  StreamSubscription<AgentBuilderEvent>? _subscription;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);
  String? get _token => widget.sessionController.gaToken;

  @override
  void initState() {
    super.initState();
    _builderRepository = SkillBuilderRepository(apiClient: widget.apiClient);
    _connectionsRepository = ConnectionsRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _loadConnections();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadConnections() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final connections = await _connectionsRepository.listConnections(token);
      if (!mounted) return;
      setState(() {
        _connections = connections;
        _connectionId = connections.isEmpty ? null : connections.first.id;
        _loadingConnections = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingConnections = false);
    }
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
          _tx('skill_builder.no_connection', 'Elige una conexión primero'),
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
        .streamChat(token, connectionId: connectionId, messages: _messages)
        .listen(
          (event) {
            if (!mounted) return;
            if (event.type == 'progress') {
              final visible = event.assistantMessage ?? '';
              setState(() {
                _stage = event.stage;
                if (visible.isNotEmpty) _partialReply = visible;
              });
              scrollToEnd(_scrollController);
            } else if (event.type == 'error') {
              setState(() {
                _error =
                    event.message ??
                    _tx(
                      'skill_builder.generic_error',
                      'Error del constructor de skills',
                    );
              });
            } else if (event.type == 'builder_done') {
              final assistantMessage = event.assistantMessage ?? '';
              setState(() {
                // Igual que en el constructor de agentes: cerrar el turno aquí
                // evita una burbuja de espera vacía junto al mensaje recibido.
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
            _handleStreamError(error, text);
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

  /// Devuelve la conversación a un estado utilizable: sin el mensaje que no
  /// llegó a responderse y con el texto del usuario de vuelta en el compositor.
  void _handleStreamError(Object error, String failedText) {
    final apiError = error is ApiError ? error : null;
    setState(() {
      _streaming = false;
      _thinking = false;
      _partialReply = '';
      _stage = null;
      _error =
          apiError?.message ??
          _tx(
            'skill_builder.connection_error',
            'Error de conexión con el constructor de skills',
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
  }

  Future<void> _reviewDraft(Map<String, dynamic> draft) async {
    final saved = await widget.onReviewDraft(draft);
    if (!mounted || !saved) return;
    setState(() {
      _skillSaved = true;
      _pendingDraft = null;
    });
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
        return _tx('skill_builder.stage_replying', 'Redactando respuesta…');
      case 'drafting':
        return _tx('skill_builder.stage_drafting', 'Preparando el borrador…');
      case 'writing_instructions':
        return _tx(
          'skill_builder.stage_writing',
          'Escribiendo el contenido de la skill…',
        );
      default:
        return _tx('skill_builder.stage_analyzing', 'Analizando tu solicitud…');
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? FncColors.materialRed.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(_tx('skill_builder.title', 'Constructor de skills IA')),
        actions: [
          if (_skillSaved)
            TertiaryButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check),
              label: Text(_tx('skill_builder.done_action', 'Terminar')),
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
            title: _tx('skill_builder.assistant_title', 'Asistente de diseño'),
            subtitle: _tx(
              'skill_builder.assistant_subtitle',
              'Define la skill y revisa el borrador antes de crearla',
            ),
            partialReply: _partialReply,
            thinkingLabel: _thinkingLabel,
            draft: _pendingDraft,
            draftTitle: _tx('skill_builder.draft_ready', 'Borrador propuesto'),
            draftActionLabel: _tx(
              'skill_builder.draft_review',
              'Revisar y crear',
            ),
            onReviewDraft: _pendingDraft == null
                ? null
                : () => _reviewDraft(_pendingDraft!),
            intro: _tx(
              'skill_builder.intro',
              'Describe qué debe hacer la skill y cuándo debería utilizarse.',
            ),
            inputHint: _tx(
              'skill_builder.input_hint',
              'Describe la skill que quieres crear…',
            ),
            sendTooltip: _tx('skill_builder.send', 'Enviar mensaje'),
            stopTooltip: _tx('skill_builder.stop', 'Detener respuesta'),
            suggestions: [
              _tx(
                'skill_builder.suggestion_review',
                'Revisar código antes de entregarlo',
              ),
              _tx(
                'skill_builder.suggestion_meetings',
                'Preparar resúmenes de reuniones',
              ),
              _tx(
                'skill_builder.suggestion_research',
                'Investigar y contrastar fuentes',
              ),
            ],
            error: _error,
          );

          return Center(
            child: ConstrainedBox(
              // Ancho de lectura, no de pantalla: el texto es el contenido.
              constraints: const BoxConstraints(maxWidth: 760),
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
                      emptyMessagePath: 'skill_builder.connection_required',
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
}
