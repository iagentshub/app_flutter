import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../features/agents/widgets/agent_builder_chat_panel.dart';
import '../../../features/connections/repositories/connections_repository.dart';
import '../../../models/agents/agent_builder_models.dart';
import '../../../models/chat/chat_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
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
    });
    _scrollToEnd();

    final completer = Completer<void>();
    _subscription = _builderRepository
        .streamChat(token, connectionId: connectionId, messages: _messages)
        .listen(
          (event) async {
            if (!mounted) return;
            if (event.type == 'progress') {
              _scrollToEnd();
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
                _thinking = false;
                if (assistantMessage.isNotEmpty) {
                  _messages.add(
                    ChatMessage(role: 'assistant', content: assistantMessage),
                  );
                }
              });
              _scrollToEnd();
              if (event.isReady && event.draft != null) {
                final saved = await widget.onReviewDraft(event.draft!);
                if (mounted && saved) {
                  setState(() => _skillSaved = true);
                }
              }
            }
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _error = _tx(
                'skill_builder.connection_error',
                'Error de conexión con el constructor de skills',
              );
            });
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
                _tx('skill_builder.setup_title', 'Configura tu skill'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                _tx(
                  'skill_builder.setup_subtitle',
                  'Elige el modelo que te ayudará a diseñarla.',
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
                      (connection) => DropdownMenuItem<String>(
                        value: connection.id,
                        child: Text(
                          '${connection.name} (${connection.type})',
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
                  'skill_builder.connection_required',
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
                _tx('skill_builder.step_describe', 'Describe la capacidad'),
              ),
              _buildStep(
                Icons.tune,
                '2',
                _tx('skill_builder.step_refine', 'Responde y afina detalles'),
              ),
              _buildStep(
                Icons.fact_check_outlined,
                '3',
                _tx('skill_builder.step_review', 'Revisa el borrador'),
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
            title: _tx('skill_builder.assistant_title', 'Asistente de diseño'),
            subtitle: _tx(
              'skill_builder.assistant_subtitle',
              'Te hará preguntas y preparará un borrador editable',
            ),
            intro: _tx(
              'skill_builder.intro',
              'Describe qué capacidad reutilizable quieres crear. El asistente '
                  'preparará unas instrucciones que podrás revisar antes de guardarlas.',
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
}
