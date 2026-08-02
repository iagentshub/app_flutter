import 'package:app_flutter/features/workflows/models/workflow_run_state.dart';
import 'package:app_flutter/features/workflows/models/workflow_step_draft.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 1, 1, 12);
DateTime _at(int seconds) => _t0.add(Duration(seconds: seconds));

List<WorkflowStepDraft> _pipeline() => [
  WorkflowStepDraft(id: 'a', agentId: 'ag-1', nextStepIds: ['b']),
  WorkflowStepDraft(id: 'b', agentId: 'ag-2', nextStepIds: ['c']),
  WorkflowStepDraft(
    id: 'c',
    agentId: 'ag-3',
    kind: 'evaluator',
    evaluatorCondition: 'está completo',
    loopTargetId: 'b',
  ),
];

void main() {
  test('arranca con todos los nodos pendientes', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    expect(state.status.values, everyElement(RunNodeStatus.waiting));
    expect(state.totalCount, 3);
    expect(state.completedCount, 0);
    expect(state.running, isTrue);
  });

  test(
    'los heartbeats no ensucian el timeline pero sí marcan señal de vida',
    () {
      final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
      final changed = state.apply({'type': 'heartbeat'}, _at(10));
      expect(changed, isFalse);
      expect(state.timeline, isEmpty);
      expect(state.lastSignalAt, _at(10));
    },
  );

  test('un paso pasa a en curso y luego a completado, con su duración', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    state.apply({
      'type': 'stage_started',
      'node_id': 'a',
      'agent_name': 'Analista',
      'iteration': 1,
    }, _at(1));
    expect(state.status['a'], RunNodeStatus.running);
    expect(state.activeNodeId, 'a');

    state.apply({
      'type': 'stage_done',
      'node_id': 'a',
      'agent_name': 'Analista',
      'output': 'resultado',
      'iteration': 1,
    }, _at(6));
    expect(state.status['a'], RunNodeStatus.done);
    expect(state.outputs['a'], 'resultado');
    expect(state.durations['a'], const Duration(seconds: 5));
    expect(state.completedCount, 1);
  });

  test('el evaluador rechazado se marca completado y guarda el motivo', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    state.apply({'type': 'evaluation_started', 'node_id': 'c'}, _at(1));
    state.apply({
      'type': 'evaluation_done',
      'node_id': 'c',
      'approved': false,
      'reason': 'Falta la sección de riesgos',
      'iteration': 1,
    }, _at(3));

    // Antes se quedaba en `running` y se pintaba colgado para siempre.
    expect(state.status['c'], RunNodeStatus.done);
    expect(state.evaluatorApproved['c'], isFalse);
    expect(state.evaluatorReasons['c'], 'Falta la sección de riesgos');
  });

  test('el rebobinado de ciclo devuelve el cuerpo a pendiente', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    for (final id in ['a', 'b']) {
      state.apply({'type': 'stage_started', 'node_id': id}, _at(1));
      state.apply({
        'type': 'stage_done',
        'node_id': id,
        'output': 'salida $id',
      }, _at(2));
    }
    state.apply({
      'type': 'evaluation_done',
      'node_id': 'c',
      'approved': false,
      'reason': 'otra vuelta',
      'iteration': 1,
    }, _at(3));
    state.apply({
      'type': 'loop_iteration_started',
      'node_id': 'c',
      'target_node_id': 'b',
      'iteration': 2,
    }, _at(4));

    // El cuerpo del ciclo es {b, c}: `a` está fuera y conserva su salida.
    expect(state.status['b'], RunNodeStatus.running);
    expect(state.status['c'], RunNodeStatus.waiting);
    expect(state.outputs.containsKey('c'), isFalse);
    expect(state.status['a'], RunNodeStatus.done);
    expect(state.outputs['a'], 'salida a');
    expect(state.iterations['c'], 2);
    expect(state.maxIteration, 2);
  });

  test('workflow_done cierra el run y guarda la salida final', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    state.apply({'type': 'workflow_done', 'output': 'informe final'}, _at(20));
    expect(state.running, isFalse);
    expect(state.finalOutput, 'informe final');
    expect(state.activeNodeId, isNull);
    expect(state.elapsed, const Duration(seconds: 20));
  });

  test('loop_limit_reached marca error en el nodo y detiene el run', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    state.apply({
      'type': 'loop_limit_reached',
      'node_id': 'c',
      'iteration': 5,
      'message': 'El evaluador no aprobó en 5 vueltas',
    }, _at(9));
    expect(state.status['c'], RunNodeStatus.error);
    expect(state.error, 'El evaluador no aprobó en 5 vueltas');
    expect(state.running, isFalse);
  });

  test('cancelar detiene el run y suelta el nodo en curso', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    state.apply({'type': 'stage_started', 'node_id': 'a'}, _at(1));
    state.markCancelled(_at(4));

    expect(state.cancelled, isTrue);
    expect(state.running, isFalse);
    expect(state.status['a'], RunNodeStatus.waiting);
    expect(state.timeline.last.type, 'cancelled');
  });

  test('un error de stream no pisa un run ya terminado', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    state.apply({'type': 'workflow_done', 'output': 'ok'}, _at(5));
    state.markStreamError('conexión perdida', _at(6));
    expect(state.error, isNull);
    expect(state.finalOutput, 'ok');
  });

  test('cada evaluación del timeline guarda su propio veredicto', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    state.apply({
      'type': 'evaluation_done',
      'node_id': 'c',
      'approved': false,
      'reason': 'falta algo',
      'iteration': 1,
    }, _at(3));
    state.apply({
      'type': 'evaluation_done',
      'node_id': 'c',
      'approved': true,
      'reason': 'ahora sí',
      'iteration': 2,
    }, _at(9));

    // El registro no puede reescribir el pasado: la primera vuelta fue un
    // rechazo aunque la segunda aprobara.
    final verdicts = state.timeline
        .where((entry) => entry.type == 'evaluation_done')
        .map((entry) => entry.approved)
        .toList();
    expect(verdicts, [false, true]);
    expect(state.evaluatorApproved['c'], isTrue);
  });

  test('el timeline conserva el orden y los tiempos relativos', () {
    final state = WorkflowRunState(steps: _pipeline(), startedAt: _t0);
    state.apply({'type': 'stage_started', 'node_id': 'a'}, _at(2));
    state.apply({'type': 'heartbeat'}, _at(5));
    state.apply({'type': 'stage_done', 'node_id': 'a', 'output': 'x'}, _at(8));

    expect(state.timeline.map((entry) => entry.type), [
      'stage_started',
      'stage_done',
    ]);
    expect(state.timeline.first.at, const Duration(seconds: 2));
    expect(state.timeline.last.at, const Duration(seconds: 8));
  });
}
