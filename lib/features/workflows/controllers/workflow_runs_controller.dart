import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/state/session_controller.dart';
import '../models/workflow_run.dart';
import '../repositories/workflows_repository.dart';

class WorkflowRunsController extends ChangeNotifier {
  WorkflowRunsController({
    required ApiClient apiClient,
    required SessionController sessionController,
    bool autoStart = true,
  }) : _repository = WorkflowsRepository(apiClient: apiClient),
       _apiClient = apiClient,
       _session = sessionController {
    _lastIdentity = _identity;
    if (autoStart) {
      _session.addListener(_identityChanged);
      _apiClient.backendController.addListener(_identityChanged);
      _timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
      scheduleMicrotask(refresh);
    }
  }

  final WorkflowsRepository _repository;
  final ApiClient _apiClient;
  final SessionController _session;
  Timer? _timer;
  bool _loading = false;
  List<WorkflowRun> _runs = const [];
  late String _lastIdentity;

  List<WorkflowRun> get runs => _runs;
  List<WorkflowRun> get activeRuns => _runs.where((run) => run.active).toList();
  int get activeCount => activeRuns.length;
  bool get loading => _loading;

  String? get _token {
    final value = _session.gaToken;
    return value == null || value.isEmpty ? null : value;
  }

  String get _identity =>
      '${_apiClient.backendController.selectedBackendId}|${_session.cacheIdentity}|${_token == null ? 0 : 1}';

  void _identityChanged() {
    final next = _identity;
    if (next == _lastIdentity) return;
    _lastIdentity = next;
    _runs = const [];
    notifyListeners();
    refresh();
  }

  Future<void> refresh() async {
    final token = _token;
    if (token == null || _loading) return;
    _loading = true;
    try {
      _runs = await _repository.listRuns(token);
      notifyListeners();
    } catch (_) {
      // El indicador conserva el último estado conocido durante cortes breves.
    } finally {
      _loading = false;
    }
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _session.removeListener(_identityChanged);
    _apiClient.backendController.removeListener(_identityChanged);
    super.dispose();
  }
}
