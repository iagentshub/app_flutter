import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/diagnostics/app_diagnostics.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/state/session_controller.dart';
import '../models/workflow_run.dart';
import '../repositories/workflows_repository.dart';

class WorkflowRunsController extends ChangeNotifier {
  WorkflowRunsController({
    required ApiClient apiClient,
    required SessionController sessionController,
    bool autoStart = true,
    this._activePollInterval = const Duration(seconds: 5),
    this._idlePollInterval = const Duration(minutes: 1),
  }) : _repository = WorkflowsRepository(apiClient: apiClient),
       _apiClient = apiClient,
       _session = sessionController,
       _autoStart = autoStart {
    _lastIdentity = _identity;
    if (autoStart) {
      _session.addListener(_identityChanged);
      _apiClient.backendController.addListener(_identityChanged);
      scheduleMicrotask(refresh);
    }
  }

  final WorkflowsRepository _repository;
  final ApiClient _apiClient;
  final SessionController _session;
  final bool _autoStart;
  final Duration _activePollInterval;
  final Duration _idlePollInterval;
  Timer? _timer;
  bool _loading = false;
  bool _refreshQueued = false;
  bool _disposed = false;
  int _generation = 0;
  List<WorkflowRun> _runs = const [];
  late String _lastIdentity;
  Duration? _nextPollDelay;

  List<WorkflowRun> get runs => _runs;
  List<WorkflowRun> get activeRuns => _runs.where((run) => run.active).toList();
  int get activeCount => activeRuns.length;
  bool get loading => _loading;

  @visibleForTesting
  Duration? get debugNextPollDelay => _nextPollDelay;

  String? get _token {
    // Las credenciales restauradas no habilitan trabajo autenticado hasta que
    // `/api/auth/me` las haya validado. Esto evita sondeos internos mientras
    // la app muestra la compuerta de restauración o el backend está caído.
    if (!_session.isLoggedIn) return null;
    final value = _session.gaToken;
    return value == null || value.isEmpty ? null : value;
  }

  String get _identity =>
      '${_apiClient.backendController.selectedBackendId}|${_session.cacheIdentity}|${_token == null ? 0 : 1}';

  void _identityChanged() {
    final next = _identity;
    if (next == _lastIdentity) return;
    _lastIdentity = next;
    _generation += 1;
    _timer?.cancel();
    _nextPollDelay = null;
    _runs = const [];
    notifyListeners();
    if (_token != null) unawaited(refresh());
  }

  Future<void> refresh() async {
    final token = _token;
    if (token == null || _disposed) return;
    if (_loading) {
      _refreshQueued = true;
      return;
    }
    final generation = _generation;
    _loading = true;
    try {
      final runs = await _repository.listRuns(token);
      if (_disposed || generation != _generation) return;
      _runs = runs;
      notifyListeners();
    } catch (error, stackTrace) {
      // El indicador conserva el último estado conocido durante cortes breves.
      AppDiagnostics.report('workflow_runs.refresh', error, stackTrace);
    } finally {
      _loading = false;
      if (!_disposed) {
        if (_refreshQueued) {
          _refreshQueued = false;
          unawaited(refresh());
        } else {
          _scheduleNextPoll();
        }
      }
    }
  }

  void _scheduleNextPoll() {
    if (!_autoStart || _disposed || _token == null) return;
    _timer?.cancel();
    final delay = activeRuns.isEmpty ? _idlePollInterval : _activePollInterval;
    _nextPollDelay = delay;
    _timer = Timer(delay, refresh);
  }

  Future<WorkflowRun> startRun({
    required String workflowId,
    required String input,
  }) async {
    final token = _token;
    if (token == null) throw StateError('No hay sesión activa');
    final run = await _repository.startRun(
      token,
      workflowId: workflowId,
      input: input,
    );
    _upsert(run);
    unawaited(refresh());
    return run;
  }

  Future<WorkflowRun> detail(String runId) async {
    final token = _token;
    if (token == null) throw StateError('No hay sesión activa');
    final run = await _repository.getRun(token, runId);
    _upsert(run);
    return run;
  }

  Stream<Map<String, dynamic>> events(String runId, {int after = 0}) async* {
    final token = _token;
    if (token == null) throw StateError('No hay sesión activa');
    var cursor = after;
    var retry = 0;
    while (true) {
      try {
        await for (final event in _repository.streamRunEvents(
          token,
          runId: runId,
          after: cursor,
        )) {
          final sequence = (event['sequence'] as num?)?.toInt() ?? cursor;
          if (sequence <= cursor) continue;
          cursor = sequence;
          retry = 0;
          yield event;
        }
        final run = await detail(runId);
        if (!run.active) return;
      } catch (_) {
        retry += 1;
        await Future<void>.delayed(Duration(seconds: retry.clamp(1, 5)));
      }
    }
  }

  Future<WorkflowRun> cancel(String runId) async {
    final token = _token;
    if (token == null) throw StateError('No hay sesión activa');
    final run = await _repository.cancelRun(token, runId);
    _upsert(run);
    return run;
  }

  void _upsert(WorkflowRun run) {
    _runs = [run, ..._runs.where((item) => item.id != run.id)];
    notifyListeners();
    _scheduleNextPoll();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _nextPollDelay = null;
    _session.removeListener(_identityChanged);
    _apiClient.backendController.removeListener(_identityChanged);
    super.dispose();
  }
}
