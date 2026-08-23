import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
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
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/scroll_to_end.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../../utils/i18n.dart';
import '../../executions/controllers/resource_executions_controller.dart';
import '../repositories/agents_repository.dart';
import '../repositories/chat_repository.dart';
import '../widgets/chat_composer.dart';
import '../widgets/chat_history_panel.dart';
import '../widgets/chat_message_list.dart';

part '../dialogs/connection_preference_dialog.dart';
part '../widgets/chat_mention_overlay.dart';
part 'chat_conversations.dart';
part 'chat_streaming.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    required this.agent,
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    this.executionStateController,
    super.key,
  });

  final AgentItem agent;
  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;
  final ResourceExecutionsController? executionStateController;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with StateMessaging {
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

  String _tx(String path) => _t.text(path);

  List<ChatConversation> _conversations = const [];
  String? _conversationCursor;
  bool _hasMoreConversations = false;
  bool _loadingMoreConversations = false;
  String? _conversationId;
  List<ChatMessage> _messages = [];
  String? _messageCursor;
  bool _hasOlderMessages = false;
  bool _loadingOlderMessages = false;

  /// Texto de la respuesta en curso. Es un [ValueNotifier] —y no un campo de
  /// estado— para que cada token repinte solo la burbuja que crece, en vez de
  /// toda la página (historial, cabecera, composer y lista entera).
  final _streamingReply = ValueNotifier<String>('');

  /// Acumula los tokens en O(n): concatenar cadenas por token copiaba la
  /// respuesta completa en cada paso.
  final _replyBuffer = StringBuffer();

  /// Si el usuario se ha separado del final mientras llega la respuesta; lo
  /// escucha solo el chip de "bajar al último mensaje".
  final _awayFromEnd = ValueNotifier<bool>(false);

  bool _loadingConversations = true;
  bool _loadingMessages = false;
  bool _streaming = false;
  bool _thinking = false;
  String? _error;
  String? _routingNotice;
  StreamSubscription<ChatStreamEvent>? _subscription;
  Completer<void>? _streamCompleter;

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
    widget.executionStateController?.addListener(_onExecutionStateChanged);
    _textController.addListener(_onComposerTextChanged);
    _scrollController.addListener(_onScroll);
    _bootstrap();
    _loadMentionSources();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  void _onExecutionStateChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    _awayFromEnd.value = !isAtEnd(_scrollController);
    if (_scrollController.position.extentBefore < 240) {
      unawaited(_loadOlderMessages());
    }
  }

  @override
  void dispose() {
    widget.executionStateController?.removeListener(_onExecutionStateChanged);
    _subscription?.cancel();
    if (!(_streamCompleter?.isCompleted ?? true)) {
      _streamCompleter!.complete();
    }
    _textController.removeListener(_onComposerTextChanged);
    _scrollController.removeListener(_onScroll);
    _hideMentionOverlay();
    _textController.dispose();
    _scrollController.dispose();
    _streamingReply.dispose();
    _awayFromEnd.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

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
      await showAppDialog<void>(
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
            showMessage(_tx('agents.preferences_saved'));
          },
        ),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('agents.preferences_load_error'), isError: true);
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
            tooltip: _tx('agents.preferences_tooltip'),
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
                  tooltip: _tx('agents.chat.history_tooltip'),
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
      newConversationLabel: _tx('agents.chat.new_conversation'),
      untitledConversationLabel: _tx('agents.chat.untitled_conversation'),
      tokensTooltip: _tx('agents.tokens_tooltip'),
      deleteTooltip: _tx('agents.chat.delete_conversation'),
      hasMore: _hasMoreConversations,
      loadingMore: _loadingMoreConversations,
      onLoadMore: _loadMoreConversations,
    );
  }

  /// Salida de vuelta al final cuando el usuario se ha ido a releer y la
  /// respuesta sigue llegando: el autoscroll se congela y la única forma de
  /// volver abajo no puede ser arrastrar a ciegas.
  Widget _buildJumpToEndChip() {
    return Positioned(
      right: 12,
      bottom: 12,
      child: ValueListenableBuilder<bool>(
        valueListenable: _awayFromEnd,
        builder: (context, away, _) {
          if (!away) return const SizedBox.shrink();
          return ActionChip(
            avatar: const Icon(Icons.arrow_downward, size: 16),
            label: Text(_tx('agents.chat.jump_to_last')),
            onPressed: () => scrollToEnd(_scrollController),
          );
        },
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
              label: Text(_tx('common.retry')),
            ),
          ],
        ),
      );
    }

    final copyCodeTooltip = _tx('agents.chat.copy_code_tooltip');
    final replyActionLabel = _tx('agents.chat.reply_action');
    final copyActionLabel = _tx('agents.chat.copy_action');
    final messageCopiedLabel = _tx('agents.chat.message_copied');
    final interruptedLabel = _tx('agents.chat.interrupted');
    final estimatedUsageLabel = _tx('agents.chat.estimated_usage');

    return Column(
      children: [
        Expanded(
          child: _loadingMessages
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    ChatMessageList(
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
                      interruptedLabel: interruptedLabel,
                      estimatedUsageLabel: estimatedUsageLabel,
                      loadingOlder: _loadingOlderMessages,
                    ),
                    _buildJumpToEndChip(),
                  ],
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
        if (_routingNotice != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.route_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_routingNotice!)),
              ],
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
          busy:
              !_streaming &&
              (widget.executionStateController?.isInProgress(
                    'agent',
                    widget.agent.id,
                  ) ??
                  false),
          busyLabel: _tx('common.in_progress'),
          onSend: _send,
          onStop: _stop,
          sendTooltip: _tx('agents.chat.send'),
          stopTooltip: _tx('agents.chat.stop'),
          composerHint: _tx('agents.chat.placeholder'),
          replyTo: _replyTo,
          replyToLabel: _replyTo == null ? null : _replyLabelFor(_replyTo!),
          onCancelReply: _cancelReply,
          cancelReplyTooltip: _tx('agents.chat.cancel_reply_tooltip'),
        ),
      ],
    );
  }
}
