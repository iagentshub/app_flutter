import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../core/network/api_error.dart';
import '../../../models/agents/agent_builder_models.dart';
import '../../../models/chat/chat_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/session_controller.dart';
import '../../../utils/i18n.dart';
import '../../connections/repositories/connections_repository.dart';
import '../../knowledge/repositories/knowledge_repository.dart';
import '../../knowledge/repositories/skills_repository.dart';
import '../repositories/agent_builder_repository.dart';
import '../repositories/agents_repository.dart';

typedef AgentDraftPresenter = Future<Map<String, dynamic>?> Function(
  Map<String, dynamic> initial,
  String token,
);

/// Orquesta el constructor de agentes: recursos, conversación SSE, borrador y
/// guardado final.
///
/// El diálogo de revisión se inyecta mediante [AgentDraftPresenter] porque
/// necesita `BuildContext`. Los mensajes para SnackBar se devuelven como
/// [ActionResult]; el error de la conversación se conserva en [error] para que
/// el panel lo muestre dentro del chat.
class AgentBuilderController extends ChangeNotifier {
  AgentBuilderController({
    required this._builderRepository,
    required this._agentsRepository,
    required this._connectionsRepository,
    required this._skillsRepository,
    required this._knowledgeRepository,
    required this._sessionController,
    required this._tx,
  });

  final AgentBuilderRepository _builderRepository;
  final AgentsRepository _agentsRepository;
  final ConnectionsRepository _connectionsRepository;
  final SkillsRepository _skillsRepository;
  final KnowledgeRepository _knowledgeRepository;
  final SessionController _sessionController;
  final String Function(String path) _tx;

  final TextEditingController textController = TextEditingController();

  bool _disposed = false;
  List<ConnectionItem> _connections = const [];
  bool _loadingConnections = true;
  String? _connectionId;
  String _mode = 'auto';
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
  Completer<void>? _sendCompleter;

  // Colecciones vivas, no copias: el chat y el selector las recorren durante
  // cada build y sólo este controller las muta.
  List<ConnectionItem> get connections => _connections;
  List<ChatMessage> get messages => _messages;
  bool get loadingConnections => _loadingConnections;
  String? get connectionId => _connectionId;

  /// `auto`, `guided` o `expert`. Viaja en cada turno: el backend no guarda
  /// conversación, así que cambiarlo a mitad afecta ya al siguiente mensaje.
  String get mode => _mode;
  bool get streaming => _streaming;
  bool get thinking => _thinking;
  String get partialReply => _partialReply;
  Map<String, dynamic>? get pendingDraft => _pendingDraft;
  String? get error => _error;
  bool get agentSaved => _agentSaved;
  bool get canSend => !_loadingConnections && _connectionId != null;

  String? get _token => _sessionController.gaToken;

  void setConnectionId(String? value) {
    if (_streaming || value == _connectionId) return;
    _connectionId = value;
    _notify();
  }

  void setMode(String value) {
    if (_streaming || value == _mode) return;
    _mode = value;
    _notify();
  }

  Future<void> load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _loadingConnections = false;
      _error = _tx('common.no_session');
      _notify();
      return;
    }

    _loadingConnections = true;
    _error = null;
    _notify();
    final failures = <String>[];

    Future<T> loadResource<T>(
      String label,
      Future<T> request,
      T fallback,
    ) async {
      try {
        return await request;
      } catch (_) {
        failures.add(label);
        return fallback;
      }
    }

    final results = await Future.wait([
      loadResource(
        _tx('agents.builder_resource_connections'),
        _connectionsRepository.listConnections(token),
        const <ConnectionItem>[],
      ),
      loadResource(
        _tx('agents.builder_resource_skills'),
        _skillsRepository.listSkills(token, scope: 'all'),
        const <SkillItem>[],
      ),
      loadResource(
        _tx('agents.builder_resource_knowledge'),
        _knowledgeRepository.listItems(token),
        const <KnowledgeItem>[],
      ),
    ]);
    if (_disposed) return;

    final connections = results[0] as List<ConnectionItem>;
    _connections = connections;
    _connectionId = connections.isNotEmpty ? connections.first.id : null;
    _skillsCatalog = (results[1] as List<SkillItem>)
        .map((skill) => {'id': skill.id, 'name': skill.name})
        .toList();
    _knowledgeCatalog = (results[2] as List<KnowledgeItem>)
        .map((item) => {'id': item.id, 'name': item.title})
        .toList();
    _loadingConnections = false;
    if (failures.isNotEmpty) {
      _error =
          '${_tx('agents.builder_load_failed')}: '
          '${failures.join(', ')}';
    }
    _notify();
  }

  Future<ActionResult?> sendSuggestion(String suggestion) {
    textController.text = suggestion;
    textController.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
    return send();
  }

  Future<ActionResult?> send() async {
    final token = _token;
    final selectedConnectionId = _connectionId;
    final text = textController.text.trim();
    if (selectedConnectionId == null) {
      return ActionResult.error(_tx('agents.builder_no_connection'));
    }
    if (token == null || token.isEmpty || text.isEmpty || _streaming) {
      return null;
    }

    textController.clear();
    _error = null;
    _messages.add(ChatMessage(role: 'user', content: text));
    _streaming = true;
    _thinking = true;
    _partialReply = '';
    _stage = null;
    _pendingDraft = null;
    _notify();

    final completer = Completer<void>();
    _sendCompleter = completer;

    void completeSend() {
      if (!completer.isCompleted) completer.complete();
      if (identical(_sendCompleter, completer)) _sendCompleter = null;
    }

    _subscription = _builderRepository
        .streamChat(
          token,
          connectionId: selectedConnectionId,
          messages: _messages,
          skills: _skillsCatalog,
          knowledge: _knowledgeCatalog,
          mode: _mode,
        )
        .listen(
          _handleEvent,
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed) {
              completeSend();
              return;
            }
            unawaited(
              _handleStreamError(
                error,
                selectedConnectionId,
                text,
              ).whenComplete(completeSend),
            );
          },
          onDone: () {
            if (!_disposed) {
              _streaming = false;
              _thinking = false;
              _notify();
            }
            completeSend();
          },
          cancelOnError: true,
        );

    await completer.future;
    return null;
  }

  void _handleEvent(AgentBuilderEvent event) {
    if (_disposed) return;
    if (event.type == 'progress') {
      final visible = event.assistantMessage ?? '';
      _stage = event.stage;
      if (event.stage == null) {
        // Un `progress` sin fase es la señal de que el backend empieza otro
        // intento. Sin limpiar aquí, el mensaje parcial del intento que acaba
        // de fallar se quedaba en pantalla durante todo el segundo.
        _partialReply = '';
      } else if (visible.isNotEmpty) {
        _partialReply = visible;
      }
    } else if (event.type == 'error') {
      _error = trErrorOr(
        event.code,
        event.message ?? _tx('agents.builder_generic_error'),
      );
    } else if (event.type == 'builder_done') {
      final assistantMessage = event.assistantMessage ?? '';
      // Cerrar el turno aquí y no en onDone evita una burbuja de espera vacía
      // junto al mensaje que ya se recibió.
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
    } else {
      return;
    }
    _notify();
  }

  Future<void> _handleStreamError(
    Object error,
    String failedConnectionId,
    String failedText,
  ) async {
    if (_disposed) return;
    final apiError = error is ApiError ? error : null;
    _streaming = false;
    _thinking = false;
    _partialReply = '';
    _stage = null;
    _error = apiError?.message ?? _tx('agents.builder_connection_error');
    if (_messages.isNotEmpty &&
        _messages.last.role == 'user' &&
        _messages.last.content == failedText) {
      _messages.removeLast();
    }
    if (textController.text.isEmpty) {
      textController.text = failedText;
      textController.selection = TextSelection.collapsed(
        offset: failedText.length,
      );
    }
    _notify();

    if (apiError?.statusCode != 404) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final refreshed = await _connectionsRepository.listConnections(
        token,
        cache: false,
      );
      if (_disposed) return;
      final available = refreshed
          .where((connection) => connection.id != failedConnectionId)
          .toList();
      _connections = available;
      if (!available.any((connection) => connection.id == _connectionId)) {
        _connectionId = available.isNotEmpty ? available.first.id : null;
      }
      _notify();
    } catch (_) {
      // Se conserva el error original, más útil que un segundo fallo al
      // refrescar el selector.
    }
  }

  Future<ActionResult?> reviewDraft({
    required AgentDraftPresenter present,
  }) async {
    final token = _token;
    final draft = _pendingDraft;
    if (token == null || token.isEmpty || draft == null) return null;

    final name = (draft['name'] as String? ?? '').trim();
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final useMemory = draft['use_memory'] == true;
    // La conexión del constructor se elige por rapidez para redactar, no para
    // ejecutar el agente, y se heredaba sin decirlo: quien usaba un modelo
    // pequeño para diseñar acababa con el agente corriendo en él. Se hereda
    // solo cuando no hay nada que decidir; con varias, la elige el usuario en
    // el formulario, igual que al crear un agente a mano.
    final inheritedConnection = _connections.length == 1
        ? _connections.single.id
        : '';
    final initial = <String, dynamic>{
      ...draft,
      'connection_id': inheritedConnection,
      'memory_file': useMemory && slug.isNotEmpty ? '$slug.md' : '',
    };

    final payload = await present(initial, token);
    if (payload == null || _disposed) return null;
    try {
      await _agentsRepository.saveAgent(token, payload);
      if (_disposed) return null;
      _agentSaved = true;
      _pendingDraft = null;
      _notify();
      return ActionResult(_tx('agents.builder_agent_created'));
    } on ApiError catch (error) {
      return ActionResult.error(error.message);
    } catch (_) {
      return ActionResult.error(_tx('agents.error_generic_save'));
    }
  }

  void stop() {
    final cancellation = _subscription?.cancel();
    _subscription = null;
    if (cancellation != null) unawaited(cancellation);
    final completer = _sendCompleter;
    _sendCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    _streaming = false;
    _thinking = false;
    _partialReply = '';
    _stage = null;
    _notify();
  }

  /// Etiqueta de espera correspondiente a la fase informada por el backend.
  String get thinkingLabel {
    switch (_stage) {
      case 'replying':
        return _tx('agents.builder_stage_replying');
      case 'drafting':
        return _tx('agents.builder_stage_drafting');
      case 'writing_instructions':
        return _tx('agents.builder_stage_writing');
      default:
        return _tx('agents.builder_stage_analyzing');
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final cancellation = _subscription?.cancel();
    _subscription = null;
    if (cancellation != null) unawaited(cancellation);
    final completer = _sendCompleter;
    _sendCompleter = null;
    if (completer != null && !completer.isCompleted) completer.complete();
    textController.dispose();
    super.dispose();
  }
}
