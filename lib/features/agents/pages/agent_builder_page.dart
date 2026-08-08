import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/scroll_to_end.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../connections/repositories/connections_repository.dart';
import '../../knowledge/repositories/knowledge_repository.dart';
import '../../knowledge/repositories/skills_repository.dart';
import '../controllers/agent_builder_controller.dart';
import '../repositories/agent_builder_repository.dart';
import '../repositories/agents_repository.dart';
import '../widgets/agent_builder_chat_panel.dart';
import '../widgets/builder_connection_bar.dart';
import 'agent_form_page.dart';

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
  late final AgentBuilderController _controller;
  late final TranslatedTexts _t;
  final _scrollController = ScrollController();

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _controller = AgentBuilderController(
      builderRepository: AgentBuilderRepository(apiClient: widget.apiClient),
      agentsRepository: AgentsRepository(apiClient: widget.apiClient),
      connectionsRepository: ConnectionsRepository(apiClient: widget.apiClient),
      skillsRepository: SkillsRepository(apiClient: widget.apiClient),
      knowledgeRepository: KnowledgeRepository(apiClient: widget.apiClient),
      sessionController: widget.sessionController,
      tx: _tx,
    )..addListener(_onControllerChanged);
    unawaited(_controller.load());
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    scrollToEnd(_scrollController);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _scrollController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  Future<void> _runAction(Future<ActionResult?> action) async {
    final result = await action;
    if (!mounted || result == null) return;
    showMessage(result.message, isError: result.isError);
  }

  void _send() => unawaited(_runAction(_controller.send()));

  void _sendSuggestion(String suggestion) =>
      unawaited(_runAction(_controller.sendSuggestion(suggestion)));

  void _openDraftReview() {
    unawaited(
      _runAction(
        _controller.reviewDraft(
          present: (initial, token) =>
              Navigator.of(context).push<Map<String, dynamic>>(
                MaterialPageRoute(
                  builder: (context) => AgentFormPage(
                    apiClient: widget.apiClient,
                    token: token,
                    initial: initial,
                    tx: _tx,
                    requireQualityPrompt: true,
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildModernPage(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(_tx('agents.builder_title', 'Constructor de agentes IA')),
        actions: [
          if (_controller.agentSaved)
            compact
                ? AppIconButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check),
                    tooltip: _tx('agents.builder_done_action', 'Terminar'),
                  )
                : TertiaryButton.icon(
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
            messages: _controller.messages,
            streaming: _controller.streaming,
            thinking: _controller.thinking,
            enabled: _controller.canSend,
            textController: _controller.textController,
            scrollController: _scrollController,
            onSend: _send,
            onStop: _controller.stop,
            onSuggestion: _sendSuggestion,
            title: _tx('agents.builder_assistant_title', 'Asistente de diseño'),
            subtitle: _tx(
              'agents.builder_assistant_subtitle',
              'Define el agente y revisa el borrador antes de crearlo',
            ),
            partialReply: _controller.partialReply,
            thinkingLabel: _controller.thinkingLabel,
            draft: _controller.pendingDraft,
            draftTitle: _tx('agents.builder_draft_ready', 'Borrador propuesto'),
            draftActionLabel: _tx(
              'agents.builder_draft_review',
              'Revisar y crear',
            ),
            onReviewDraft: _controller.pendingDraft == null
                ? null
                : _openDraftReview,
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
            error: _controller.error,
          );

          return Center(
            child: ConstrainedBox(
              // Ancho de lectura, no de pantalla: el texto es el contenido.
              // 1040 en vez de 760 para no desperdiciar tanto margen en
              // pantallas anchas mientras las líneas siguen siendo legibles.
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact
                      ? 0
                      : wide
                      ? 24
                      : 16,
                ),
                child: Column(
                  children: [
                    BuilderConnectionBar(
                      loadingConnections: _controller.loadingConnections,
                      streaming: _controller.streaming,
                      connections: _controller.connections,
                      connectionId: _controller.connectionId,
                      onConnectionChanged: _controller.setConnectionId,
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
