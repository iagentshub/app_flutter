import '../../../utils/i18n.dart';

import 'workflow_step_draft.dart';

/// Estado de un nodo durante una ejecución.
enum RunNodeStatus { waiting, running, done, error }

/// Una entrada del registro de eventos que emite el motor por SSE.
class RunTimelineEntry {
  const RunTimelineEntry({
    required this.type,
    required this.at,
    this.nodeId,
    this.label,
    this.detail,
    this.approved,
  });

  /// Tipo tal cual lo manda `backend/app/services/workflow_runner.py`.
  final String type;

  /// Tiempo transcurrido desde el inicio del run.
  final Duration at;

  final String? nodeId;
  final String? label;
  final String? detail;

  /// Veredicto en el momento del evento, solo para `evaluation_done`.
  ///
  /// Se guarda aquí y no se lee del estado: un evaluador que rechaza y luego
  /// aprueba dejaría el registro entero diciendo "aprobada".
  final bool? approved;
}

/// Reduce el stream de eventos del motor a algo pintable.
///
/// Vive fuera del widget para poder probarlo sin levantar Flutter y para que el
/// diálogo se quede en presentación pura. Los tipos de evento son los que emite
/// `run_workflow` en `backend/app/services/workflow_runner.py`.
class WorkflowRunState {
  WorkflowRunState({
    required List<WorkflowStepDraft> steps,
    DateTime? startedAt,
  }) : _steps = steps,
       startedAt = startedAt ?? DateTime.now() {
    for (final step in _steps) {
      status[step.id] = RunNodeStatus.waiting;
    }
  }

  final List<WorkflowStepDraft> _steps;
  final DateTime startedAt;

  final Map<String, RunNodeStatus> status = {};
  final Map<String, String> outputs = {};
  final Map<String, int> iterations = {};
  final Map<String, Duration> durations = {};
  final Map<String, bool> evaluatorApproved = {};
  final Map<String, String> evaluatorReasons = {};
  final List<RunTimelineEntry> timeline = [];

  final Map<String, DateTime> _startedAt = {};

  String? activeNodeId;
  String? finalOutput;
  String? error;
  bool running = true;
  bool cancelled = false;

  /// Último instante en que el servidor dio señales de vida, incluidos los
  /// `heartbeat`. Sirve para distinguir "pensando" de "colgado".
  late DateTime lastSignalAt = startedAt;

  /// Desde cuándo lleva corriendo el nodo activo.
  DateTime? get activeSince {
    final id = activeNodeId;
    return id == null ? null : _startedAt[id];
  }

  int get completedCount =>
      status.values.where((value) => value == RunNodeStatus.done).length;

  int get totalCount => _steps.length;

  /// Vuelta más alta alcanzada; > 1 significa que algún ciclo ha rebobinado.
  int get maxIteration =>
      iterations.values.fold(1, (best, value) => value > best ? value : best);

  Duration get elapsed => lastSignalAt.difference(startedAt);

  void markCancelled(DateTime now) {
    if (!running) return;
    cancelled = true;
    running = false;
    lastSignalAt = now;
    final active = activeNodeId;
    if (active != null && status[active] == RunNodeStatus.running) {
      status[active] = RunNodeStatus.waiting;
    }
    timeline.add(
      RunTimelineEntry(type: 'cancelled', at: now.difference(startedAt)),
    );
  }

  void markStreamError(String message, DateTime now) {
    if (!running) return;
    error = message;
    running = false;
    lastSignalAt = now;
    final active = activeNodeId;
    if (active != null) status[active] = RunNodeStatus.error;
    timeline.add(
      RunTimelineEntry(
        type: 'error',
        at: now.difference(startedAt),
        detail: message,
      ),
    );
  }

  void markStreamClosed(DateTime now) {
    if (!running) return;
    running = false;
    lastSignalAt = now;
  }

  /// Aplica un evento del stream. Devuelve `false` si no cambia nada visible
  /// (heartbeats), para que la UI pueda evitar repintados innecesarios.
  bool apply(Map<String, dynamic> event, DateTime now) {
    lastSignalAt = now;
    final type = event['type']?.toString() ?? '';
    if (type == 'heartbeat') return false;

    final nodeId = event['node_id']?.toString() ?? '';
    final label = event['agent_name']?.toString();
    if (nodeId.isNotEmpty && event['iteration'] is num) {
      iterations[nodeId] = (event['iteration'] as num).toInt();
    }
    final at = now.difference(startedAt);

    switch (type) {
      case 'stage_started':
      case 'evaluation_started':
        activeNodeId = nodeId;
        if (nodeId.isNotEmpty) {
          status[nodeId] = RunNodeStatus.running;
          _startedAt[nodeId] = now;
        }
        break;

      case 'stage_done':
        activeNodeId = nodeId;
        if (nodeId.isNotEmpty) {
          status[nodeId] = RunNodeStatus.done;
          outputs[nodeId] = event['output']?.toString() ?? '';
          _recordDuration(nodeId, now);
        }
        break;

      case 'evaluation_done':
        activeNodeId = nodeId;
        if (nodeId.isNotEmpty) {
          final approved = event['approved'] == true;
          // Un evaluador que rechaza ha terminado su turno igual que uno que
          // aprueba: lo que sigue es el rebobinado del ciclo, que devolverá el
          // scope a `waiting`. Dejarlo en `running` lo pintaba colgado.
          status[nodeId] = RunNodeStatus.done;
          evaluatorApproved[nodeId] = approved;
          final reason = event['reason']?.toString();
          if (reason != null && reason.trim().isNotEmpty) {
            evaluatorReasons[nodeId] = reason;
          }
          _recordDuration(nodeId, now);
        }
        break;

      case 'loop_iteration_started':
        final targetId = event['target_node_id']?.toString() ?? '';
        for (final id in _loopScope(nodeId, targetId)) {
          status[id] = id == targetId
              ? RunNodeStatus.running
              : RunNodeStatus.waiting;
          if (id != targetId) {
            outputs.remove(id);
            durations.remove(id);
          }
        }
        activeNodeId = targetId.isEmpty ? nodeId : targetId;
        if (targetId.isNotEmpty) _startedAt[targetId] = now;
        break;

      case 'loop_limit_reached':
      case 'error':
        if (nodeId.isNotEmpty) status[nodeId] = RunNodeStatus.error;
        if (nodeId.isNotEmpty) activeNodeId = nodeId;
        error = _errorMessage(event);
        running = false;
        break;

      case 'workflow_done':
        finalOutput = event['output']?.toString();
        activeNodeId = null;
        running = false;
        break;
    }

    timeline.add(
      RunTimelineEntry(
        type: type,
        at: at,
        nodeId: nodeId.isEmpty ? null : nodeId,
        label: label,
        detail: _detailFor(type, event),
        approved: type == 'evaluation_done' ? event['approved'] == true : null,
      ),
    );
    return true;
  }

  void _recordDuration(String nodeId, DateTime now) {
    final started = _startedAt[nodeId];
    if (started != null) durations[nodeId] = now.difference(started);
  }

  String? _detailFor(String type, Map<String, dynamic> event) {
    if (type == 'evaluation_done') return event['reason']?.toString();
    if (type == 'loop_limit_reached' || type == 'error') {
      return _errorMessage(event);
    }
    return null;
  }

  String _errorMessage(Map<String, dynamic> event) =>
      trErrorOr(event['code']?.toString(), event['message']?.toString() ?? '');

  /// Nodos que el motor reinicia al rebobinar un ciclo.
  ///
  /// Mismo criterio que `_loop_scope` en `workflow_runner.py`: lo alcanzable
  /// hacia delante desde el destino del salto, intersecado con lo alcanzable
  /// hacia atrás desde el origen. Es decir, el cuerpo del ciclo y nada más.
  Set<String> _loopScope(String sourceId, String targetId) {
    if (targetId.isEmpty) return {sourceId};
    return _reachable(
      targetId,
      forward: true,
    ).intersection(_reachable(sourceId, forward: false));
  }

  Set<String> _reachable(String from, {required bool forward}) {
    final seen = <String>{};
    final pending = <String>[from];
    while (pending.isNotEmpty) {
      final current = pending.removeLast();
      if (!seen.add(current)) continue;
      if (forward) {
        pending.addAll(_steps.byId(current)?.nextStepIds ?? const []);
      } else {
        for (final step in _steps) {
          if (step.nextStepIds.contains(current)) pending.add(step.id);
        }
      }
    }
    return seen;
  }
}
