import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../features/connections/repositories/connections_repository.dart';
import '../../../features/knowledge/repositories/knowledge_repository.dart';
import '../../../features/knowledge/repositories/prompts_repository.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/chat/chat_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../repositories/agents_repository.dart';
import '../repositories/chat_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/scroll_to_end.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_history_panel.dart';
import '../widgets/chat_message_list.dart';

part 'chat_conversations.dart';
part 'chat_streaming.dart';
part '../dialogs/connection_preference_dialog.dart';
part '../widgets/chat_mention_overlay.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    required this.agent,
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final AgentItem agent;
  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late final ChatRepository _repository;
  late final AgentsRepository _agentsRepository;
  late final ConnectionsRepository _connectionsRepository;
  late final PromptsRepository _promptsRepository;
  late final KnowledgeRepository _knowledgeRepository;
  late final TranslatedTexts _t;
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  /// Ancla el overlay de sugerencias `@` justo debajo del composer.
  final _mentionLink = LayerLink();
  OverlayEntry? _mentionOverlay;
  List<PromptItem> _promptMentionMatches = const [];
  List<KnowledgeItem> _knowledgeMentionMatches = const [];

  /// Universo completo de menciones sugeribles: todos los prompts y
  /// conocimientos accesibles al usuario (no solo los vinculados al agente).
  List<PromptItem> _allPrompts = const [];
  List<KnowledgeItem> _allKnowledge = const [];

  /// Conocimientos adjuntados puntualmente a este mensaje vía `@` — se
  /// mandan al enviar y se limpian después, sin quedar vinculados al agente.
  List<KnowledgeItem> _attachedKnowledge = [];

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

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

  /// Mensaje al que se está respondiendo (estilo Telegram/WhatsApp): se
  /// muestra como vista previa sobre el composer y se antepone como cita al
  /// enviar, para que quede en el historial persistido por el backend.
  ChatMessage? _replyTo;

  @override
  void initState() {
    super.initState();
    _repository = ChatRepository(apiClient: widget.apiClient);
    _agentsRepository = AgentsRepository(apiClient: widget.apiClient);
    _connectionsRepository = ConnectionsRepository(apiClient: widget.apiClient);
    _promptsRepository = PromptsRepository(apiClient: widget.apiClient);
    _knowledgeRepository = KnowledgeRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _textController.addListener(_onComposerTextChanged);
    _bootstrap();
    _loadMentionSources();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  /// Expuesto a los `extension` en otros ficheros (`part of`): `setState` es
  /// `@protected` y el analizador lo marca si se llama fuera de la clase.
  void _refresh(VoidCallback update) => setState(update);

  @override
  void dispose() {
    _subscription?.cancel();
    _textController.removeListener(_onComposerTextChanged);
    _hideMentionOverlay();
    _textController.dispose();
    _scrollController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? FncColors.materialRed.shade700 : null,
      ),
    );
  }

  Future<void> _openPreferences() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final results = await Future.wait([
        _agentsRepository.getPreferredConnection(token, widget.agent.id),
        _connectionsRepository.listConnections(token),
      ]);
      if (!mounted) return;
      final currentPreference = results[0] as String?;
      final connections = results[1] as List<ConnectionItem>;
      await showDialog<void>(
        context: context,
        builder: (context) => _ConnectionPreferenceDialog(
          connections: connections,
          initialConnectionId: currentPreference,
          tx: _tx,
          onSave: (connectionId) async {
            await _agentsRepository.setPreferredConnection(
              token,
              widget.agent.id,
              connectionId,
            );
            if (!mounted) return;
            _showMessage(
              _tx('agents.preferences_saved', 'Preferencia guardada'),
            );
          },
        ),
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx(
          'agents.preferences_load_error',
          'No se pudieron cargar las preferencias',
        ),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.agent.name),
        actions: [
          AppIconButton(
            icon: const Icon(Icons.tune),
            tooltip: _tx(
              'agents.preferences_tooltip',
              'Preferencia de conexión',
            ),
            onPressed: _openPreferences,
          ),
          Builder(
            builder: (context) => LayoutBuilder(
              builder: (context, constraints) {
                if (MediaQuery.of(context).size.width >= 760) {
                  return const SizedBox.shrink();
                }
                return AppIconButton(
                  icon: const Icon(Icons.history),
                  tooltip: _tx(
                    'agents.chat.history_tooltip',
                    'Historial de conversaciones',
                  ),
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
    return ChatHistoryPanel(
      conversations: _conversations,
      activeConversationId: _conversationId,
      loading: _loadingConversations,
      onNewConversation: _newConversation,
      onSelectConversation: _selectConversation,
      onDeleteConversation: _deleteConversation,
      newConversationLabel: _tx(
        'agents.chat.new_conversation',
        'Nueva conversación',
      ),
      untitledConversationLabel: _tx(
        'agents.chat.untitled_conversation',
        'Conversación',
      ),
      tokensTooltip: _tx('agents.tokens_tooltip', 'Tokens consumidos'),
      deleteTooltip: _tx(
        'agents.chat.delete_conversation',
        'Borrar conversación',
      ),
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
            PrimaryButton.icon(
              onPressed: _bootstrap,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final copyCodeTooltip = _tx(
      'agents.chat.copy_code_tooltip',
      'Copiar código',
    );
    final replyActionLabel = _tx('agents.chat.reply_action', 'Responder');
    final copyActionLabel = _tx('agents.chat.copy_action', 'Copiar');
    final messageCopiedLabel = _tx(
      'agents.chat.message_copied',
      'Mensaje copiado',
    );

    return Column(
      children: [
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : ChatMessageList(
                  messages: _messages,
                  streaming: _streaming,
                  thinking: _thinking,
                  streamingReply: _streamingReply,
                  scrollController: _scrollController,
                  onReply: _setReply,
                  copyCodeTooltip: copyCodeTooltip,
                  replyActionLabel: replyActionLabel,
                  copyActionLabel: copyActionLabel,
                  messageCopiedLabel: messageCopiedLabel,
                ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: TextStyle(color: FncColors.materialRed.shade700),
            ),
          ),
        ChatComposer(
          textController: _textController,
          mentionLink: _mentionLink,
          attachedKnowledge: _attachedKnowledge,
          onRemoveKnowledge: (id) => setState(() {
            _attachedKnowledge = _attachedKnowledge
                .where((k) => k.id != id)
                .toList();
          }),
          streaming: _streaming,
          onSend: _send,
          onStop: _stop,
          sendTooltip: _tx('agents.chat.send', 'Enviar mensaje'),
          stopTooltip: _tx('agents.chat.stop', 'Detener respuesta'),
          replyTo: _replyTo,
          replyToLabel: _replyTo == null ? null : _replyLabelFor(_replyTo!),
          onCancelReply: _cancelReply,
          cancelReplyTooltip: _tx(
            'agents.chat.cancel_reply_tooltip',
            'Cancelar respuesta',
          ),
        ),
      ],
    );
  }
}
