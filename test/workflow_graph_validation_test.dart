import 'package:app_flutter/features/workflows/models/workflow_graph_validation.dart';
import 'package:app_flutter/features/workflows/models/workflow_step_draft.dart';
import 'package:flutter_test/flutter_test.dart';

WorkflowStepDraft _step(
  String id, {
  List<String> next = const [],
  String kind = 'agent',
  String condition = '',
  String? loopTo,
  int loopIterations = 2,
  int maxIterations = 5,
  String agentId = 'agent-1',
}) => WorkflowStepDraft(
  id: id,
  agentId: agentId,
  kind: kind,
  evaluatorCondition: condition,
  evaluatorMaxIterations: maxIterations,
  loopTargetId: loopTo,
  loopIterations: loopIterations,
  nextStepIds: [...next],
);

/// Cadena lineal a → b → c.
List<WorkflowStepDraft> _chain() => [
  _step('a', next: ['b']),
  _step('b', next: ['c']),
  _step('c'),
];

Set<String> _keys(List<WorkflowIssue> issues) =>
    issues.map((issue) => issue.key.split('.').last).toSet();

void main() {
  group('grafos válidos', () {
    test('un solo paso sin conexiones', () {
      expect(validateWorkflowGraph([_step('a')]), isEmpty);
    });

    test('cadena lineal', () {
      expect(validateWorkflowGraph(_chain()), isEmpty);
    });

    test('ramas paralelas con fan-in', () {
      final steps = [
        _step('a', next: ['b', 'c']),
        _step('b', next: ['d']),
        _step('c', next: ['d']),
        _step('d'),
      ];
      expect(validateWorkflowGraph(steps), isEmpty);
    });

    test('ciclo fijo hacia atrás', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['c'], loopTo: 'a'),
        _step('c'),
      ];
      expect(validateWorkflowGraph(steps), isEmpty);
    });

    test('evaluador que cierra un ciclo por condición', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['c']),
        _step('c', kind: 'evaluator', condition: 'está completo', loopTo: 'b'),
      ];
      expect(validateWorkflowGraph(steps), isEmpty);
    });

    test('dos ciclos disjuntos no se consideran solapados', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['c'], loopTo: 'a'),
        _step('c', next: ['d']),
        _step('d', next: ['e'], loopTo: 'c'),
        _step('e'),
      ];
      expect(validateWorkflowGraph(steps), isEmpty);
    });
  });

  group('reglas por nodo', () {
    test('sin pasos', () {
      expect(_keys(validateWorkflowGraph([])), {'validate_no_steps'});
    });

    test('más de 30 pasos', () {
      final steps = [
        for (var i = 0; i < 31; i++)
          _step('n$i', next: i == 30 ? const [] : ['n${i + 1}']),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_max_steps'),
      );
    });

    test('paso sin agente', () {
      final steps = _chain()..[1].agentId = '';
      final issues = validateWorkflowGraph(steps);
      expect(_keys(issues), contains('validate_select_agent'));
      expect(issues.first.nodeId, 'b');
    });

    test('evaluador sin condición', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', kind: 'evaluator', loopTo: 'a'),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_evaluator_condition'),
      );
    });

    test('evaluador sin ciclo por condición', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', kind: 'evaluator', condition: 'ok'),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_evaluator_loop'),
      );
    });

    test('máximo de vueltas fuera de rango', () {
      final steps = [
        _step('a', next: ['b']),
        _step(
          'b',
          kind: 'evaluator',
          condition: 'ok',
          loopTo: 'a',
          maxIterations: 40,
        ),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_max_iterations'),
      );
    });

    test('vueltas de ciclo fijo fuera de rango', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['c'], loopTo: 'a', loopIterations: 1),
        _step('c'),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_loop_iterations'),
      );
    });

    test('instrucción demasiado larga', () {
      final steps = _chain()
        ..[0].instruction = 'x' * (maxInstructionLength + 1);
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_instruction_length'),
      );
    });
  });

  group('estructura del grafo', () {
    test('un solo paso con conexiones sobrantes', () {
      final steps = [
        _step('a', next: ['a']),
      ];
      expect(validateWorkflowGraph(steps), isEmpty);
    });

    test('paso suelto: el falso negativo que se colaba al backend', () {
      // Antes `_steps.every((s) => s.nextStepIds.isEmpty)` solo saltaba si
      // NINGÚN paso conectaba; con 3 conectados y 2 sueltos pasaba.
      final steps = [..._chain(), _step('huerfano-1'), _step('huerfano-2')];
      final issues = validateWorkflowGraph(steps);
      final orphanIssues = issues
          .where((issue) => issue.key.endsWith('validate_step_disconnected'))
          .toList();
      expect(orphanIssues, hasLength(2));
      expect(orphanIssues.map((issue) => issue.nodeId).toSet(), {
        'huerfano-1',
        'huerfano-2',
      });
    });

    test('dos inicios', () {
      final steps = [
        _step('a', next: ['c']),
        _step('b', next: ['c']),
        _step('c'),
      ];
      final issues = validateWorkflowGraph(steps);
      expect(_keys(issues), contains('validate_single_start'));
      expect(
        issues
            .where((issue) => issue.key.endsWith('validate_single_start'))
            .map((issue) => issue.nodeId)
            .toSet(),
        {'a', 'b'},
      );
    });

    test('dos finales', () {
      final steps = [
        _step('a', next: ['b', 'c']),
        _step('b'),
        _step('c'),
      ];
      final issues = validateWorkflowGraph(steps);
      expect(_keys(issues), contains('validate_single_end'));
      expect(
        issues
            .where((issue) => issue.key.endsWith('validate_single_end'))
            .map((issue) => issue.nodeId)
            .toSet(),
        {'b', 'c'},
      );
    });

    test('ciclo en las aristas de secuencia', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['c']),
        _step('c', next: ['a']),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_sequence_cycle'),
      );
    });
  });

  group('ciclos', () {
    test('ciclo hacia delante', () {
      final steps = [
        _step('a', next: ['b'], loopTo: 'c'),
        _step('b', next: ['c']),
        _step('c'),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_loop_backwards'),
      );
    });

    test('ciclos solapados', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['c']),
        _step('c', next: ['d'], loopTo: 'a'),
        _step('d', next: ['e'], loopTo: 'b'),
        _step('e'),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_loops_overlap'),
      );
    });

    test('ciclos anidados', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['c']),
        _step('c', next: ['d'], loopTo: 'b'),
        _step('d', next: ['e'], loopTo: 'a'),
        _step('e'),
      ];
      expect(
        _keys(validateWorkflowGraph(steps)),
        contains('validate_loops_overlap'),
      );
    });
  });

  group('topologicalOrder y layeredLayout', () {
    test('ordena respetando las dependencias', () {
      final order = topologicalOrder(_chain());
      expect(order, ['a', 'b', 'c']);
    });

    test('devuelve null cuando hay ciclo', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['a']),
      ];
      expect(topologicalOrder(steps), isNull);
    });

    test('coloca las ramas paralelas en la misma columna', () {
      final steps = [
        _step('a', next: ['b', 'c']),
        _step('b', next: ['d']),
        _step('c', next: ['d']),
        _step('d'),
      ];
      final positions = layeredLayout(steps);
      expect(positions['b']!.dx, positions['c']!.dx);
      expect(positions['b']!.dy, isNot(positions['c']!.dy));
      expect(positions['a']!.dx, lessThan(positions['b']!.dx));
      // El fan-in queda por detrás de las dos ramas, no a su lado.
      expect(positions['d']!.dx, greaterThan(positions['b']!.dx));
    });

    test('con ciclo cae a la rejilla sin solapar nodos', () {
      final steps = [
        _step('a', next: ['b']),
        _step('b', next: ['a']),
      ];
      final positions = layeredLayout(steps);
      expect(positions, hasLength(2));
      expect(positions['a'], isNot(positions['b']));
    });
  });

  test('dos ciclos que comparten un paso se consideran solapados', () {
    // Intervalos (a..b) y (b..c): comparten `b`, así que el backend los
    // rechaza igual que nosotros.
    final steps = [
      _step('a', next: ['b']),
      _step('b', next: ['c'], loopTo: 'a'),
      _step('c', kind: 'evaluator', condition: 'listo', loopTo: 'b'),
    ];
    expect(
      _keys(validateWorkflowGraph(steps)),
      contains('validate_loops_overlap'),
    );
  });

  test('serialización ida y vuelta conserva el grafo', () {
    final steps = [
      _step('a', next: ['b']),
      _step('b', next: ['c'], loopTo: 'a', loopIterations: 4),
      _step('c', next: ['d']),
      _step('d', kind: 'evaluator', condition: 'listo', loopTo: 'c'),
    ];
    steps[0].positionX = 80;
    steps[0].positionY = 120;
    steps[1].instruction = 'Resume el resultado anterior';

    final restored = stepsFromDefinition(buildDefinition(steps));

    expect(restored.map((step) => step.id), ['a', 'b', 'c', 'd']);
    expect(restored[0].positionX, 80);
    expect(restored[0].positionY, 120);
    expect(restored[1].instruction, 'Resume el resultado anterior');
    expect(restored[1].loopTargetId, 'a');
    expect(restored[1].loopIterations, 4);
    expect(restored[3].kind, 'evaluator');
    expect(restored[3].evaluatorCondition, 'listo');
    expect(restored[3].loopTargetId, 'c');
    expect(validateWorkflowGraph(restored), isEmpty);
  });

  test('el ciclo por condición se serializa con mode=condition', () {
    final steps = [
      _step('a', next: ['b']),
      _step('b', kind: 'evaluator', condition: 'ok', loopTo: 'a'),
    ];
    final edges = (buildDefinition(steps)['edges'] as List)
        .cast<Map<String, dynamic>>();
    final loop = edges.firstWhere((edge) => edge['type'] == 'loop');
    expect(loop['mode'], 'condition');
    expect(loop.containsKey('iterations'), isFalse);
  });
}
