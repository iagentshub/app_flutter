/// Algoritmos de grafo y validación de orquestaciones.
///
/// Puerto Dart de `backend/app/services/workflow_validator.py`.
///
/// El backend valida en `POST /api/workflows` y devuelve 422. Sin esta copia el
/// usuario solo descubre el problema después de cerrar el editor y sin saber
/// qué nodo lo causa. Las reglas y los límites se mantienen alineados con el
/// validador de Python: si cambias uno, cambia el otro.
library;

import 'dart:ui' show Offset;

import 'workflow_step_draft.dart';

const int maxWorkflowNodes = 30;
const int maxInstructionLength = 2000;
const int maxConditionLength = 2000;
const int maxLabelLength = 120;
const int minLoopIterations = 2;
const int maxLoopIterations = 20;

/// Un problema que impide guardar. [nodeId] permite señalarlo en el lienzo.
class WorkflowIssue {
  const WorkflowIssue(
    this.key,
    this.fallback, {
    this.nodeId,
    this.params = const {},
  });

  /// Clave i18n bajo el namespace `resources`.
  final String key;

  /// Texto en español, redactado en línea con el mensaje del backend.
  final String fallback;

  /// Nodo al que se puede atribuir el problema, si aplica.
  final String? nodeId;

  final Map<String, String> params;

  /// Aplica [params] sobre un texto ya traducido.
  String render(String translated) {
    var result = translated;
    params.forEach((name, value) {
      result = result.replaceAll('{{$name}}', value);
    });
    return result;
  }

  @override
  String toString() => render(fallback);
}

/// Orden topológico sobre las aristas de secuencia.
///
/// Devuelve `null` si hay un ciclo o pasos inalcanzables, que es justo cuando
/// el auto-layout por capas no tiene sentido y hay que caer a la rejilla.
List<String>? topologicalOrder(List<WorkflowStepDraft> steps) {
  if (steps.isEmpty) return const [];
  final ids = {for (final step in steps) step.id};
  final outgoing = {for (final id in ids) id: <String>[]};
  final incoming = {for (final id in ids) id: 0};
  for (final step in steps) {
    for (final target in step.nextStepIds) {
      if (target == step.id || !ids.contains(target)) continue;
      outgoing[step.id]!.add(target);
      incoming[target] = incoming[target]! + 1;
    }
  }

  final queue = [
    for (final id in ids)
      if (incoming[id] == 0) id,
  ];
  final pending = Map.of(incoming);
  final ordered = <String>[];
  while (queue.isNotEmpty) {
    final current = queue.removeAt(0);
    ordered.add(current);
    for (final target in outgoing[current]!) {
      pending[target] = pending[target]! - 1;
      if (pending[target] == 0) queue.add(target);
    }
  }
  return ordered.length == ids.length ? ordered : null;
}

/// Coloca los pasos en capas siguiendo el sentido del flujo.
///
/// Capa de un nodo = 1 + la capa más alta de sus predecesores, así que las
/// ramas paralelas quedan en la misma columna y el grafo se lee de izquierda a
/// derecha. Si hay ciclo cae a la rejilla de 3 columnas, que al menos no
/// solapa nodos.
Map<String, Offset> layeredLayout(
  List<WorkflowStepDraft> steps, {
  double columnWidth = 310,
  double rowHeight = 200,
  double origin = 80,
}) {
  final order = topologicalOrder(steps);
  if (order == null) {
    return {
      for (var i = 0; i < steps.length; i++)
        steps[i].id: Offset(
          origin + (i % 3) * columnWidth,
          origin + (i ~/ 3) * rowHeight,
        ),
    };
  }

  final layer = {for (final step in steps) step.id: 0};
  for (final id in order) {
    final step = steps.byId(id);
    if (step == null) continue;
    for (final next in step.nextStepIds) {
      if (!layer.containsKey(next)) continue;
      final candidate = layer[id]! + 1;
      if (candidate > layer[next]!) layer[next] = candidate;
    }
  }

  final rowsPerLayer = <int, int>{};
  final positions = <String, Offset>{};
  for (final id in order) {
    final column = layer[id]!;
    final row = rowsPerLayer[column] ?? 0;
    rowsPerLayer[column] = row + 1;
    positions[id] = Offset(
      origin + column * columnWidth,
      origin + row * rowHeight,
    );
  }
  return positions;
}

bool _hasPath(
  String source,
  String target,
  Map<String, List<String>> outgoing,
) {
  final pending = <String>[source];
  final seen = <String>{};
  while (pending.isNotEmpty) {
    final current = pending.removeLast();
    if (current == target) return true;
    if (!seen.add(current)) continue;
    pending.addAll(outgoing[current] ?? const []);
  }
  return false;
}

/// Comprueba todas las reglas que el backend aplicará al guardar.
///
/// Lista vacía = el grafo es ejecutable.
List<WorkflowIssue> validateWorkflowGraph(List<WorkflowStepDraft> steps) {
  final issues = <WorkflowIssue>[];

  if (steps.isEmpty) {
    return [
      const WorkflowIssue(
        'workflow_editor.validate_no_steps',
        'La orquestación necesita al menos un paso',
      ),
    ];
  }
  if (steps.length > maxWorkflowNodes) {
    issues.add(
      WorkflowIssue(
        'workflow_editor.validate_max_steps',
        'Una orquestación admite como máximo {{max}} pasos',
        params: {'max': '$maxWorkflowNodes'},
      ),
    );
  }

  // ── Reglas por nodo ──────────────────────────────────────────────────────
  for (var index = 0; index < steps.length; index++) {
    final step = steps[index];
    final position = '${index + 1}';

    if (step.agentId.trim().isEmpty) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_select_agent',
          'Selecciona un agente para el paso {{step}}',
          nodeId: step.id,
          params: {'step': position},
        ),
      );
    }
    if (step.label.length > maxLabelLength) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_label_length',
          'La etiqueta del paso {{step}} supera los {{max}} caracteres',
          nodeId: step.id,
          params: {'step': position, 'max': '$maxLabelLength'},
        ),
      );
    }
    if (step.instruction.length > maxInstructionLength) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_instruction_length',
          'La instrucción del paso {{step}} supera los {{max}} caracteres',
          nodeId: step.id,
          params: {'step': position, 'max': '$maxInstructionLength'},
        ),
      );
    }

    if (step.isEvaluator) {
      if (step.evaluatorCondition.trim().isEmpty) {
        issues.add(
          WorkflowIssue(
            'workflow_editor.validate_evaluator_condition',
            'El paso {{step}} es un evaluador y necesita una condición',
            nodeId: step.id,
            params: {'step': position},
          ),
        );
      }
      if (step.evaluatorCondition.length > maxConditionLength) {
        issues.add(
          WorkflowIssue(
            'workflow_editor.validate_condition_length',
            'La condición del paso {{step}} supera los {{max}} caracteres',
            nodeId: step.id,
            params: {'step': position, 'max': '$maxConditionLength'},
          ),
        );
      }
      // Cada evaluador debe cerrar exactamente un ciclo por condición
      // (workflow_validator.py:233-240).
      if (step.loopTargetId == null) {
        issues.add(
          WorkflowIssue(
            'workflow_editor.validate_evaluator_loop',
            'El paso {{step}} es un evaluador y debe volver a un paso anterior',
            nodeId: step.id,
            params: {'step': position},
          ),
        );
      }
      if (step.evaluatorMaxIterations < minLoopIterations ||
          step.evaluatorMaxIterations > maxLoopIterations) {
        issues.add(
          WorkflowIssue(
            'workflow_editor.validate_max_iterations',
            'El máximo de vueltas del paso {{step}} debe estar entre '
                '{{min}} y {{max}}',
            nodeId: step.id,
            params: {
              'step': position,
              'min': '$minLoopIterations',
              'max': '$maxLoopIterations',
            },
          ),
        );
      }
    } else if (step.loopTargetId != null &&
        (step.loopIterations < minLoopIterations ||
            step.loopIterations > maxLoopIterations)) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_loop_iterations',
          'Las vueltas del ciclo del paso {{step}} deben estar entre '
              '{{min}} y {{max}}',
          nodeId: step.id,
          params: {
            'step': position,
            'min': '$minLoopIterations',
            'max': '$maxLoopIterations',
          },
        ),
      );
    }
  }

  // ── Estructura del grafo ─────────────────────────────────────────────────
  final ids = {for (final step in steps) step.id};
  final outgoing = {for (final id in ids) id: <String>[]};
  final incoming = {for (final id in ids) id: 0};
  var sequenceCount = 0;
  for (final step in steps) {
    for (final target in step.nextStepIds) {
      if (target == step.id || !ids.contains(target)) continue;
      outgoing[step.id]!.add(target);
      incoming[target] = incoming[target]! + 1;
      sequenceCount += 1;
    }
  }

  if (steps.length == 1) {
    if (sequenceCount > 0) {
      issues.add(
        const WorkflowIssue(
          'workflow_editor.validate_single_step_no_edges',
          'Una orquestación de un solo paso no necesita conexiones',
        ),
      );
    }
    return issues;
  }

  // Todos los pasos deben estar conectados (workflow_validator.py:58-59).
  if (sequenceCount < steps.length - 1) {
    final orphans = [
      for (final step in steps)
        if (incoming[step.id] == 0 && outgoing[step.id]!.isEmpty) step,
    ];
    if (orphans.isEmpty) {
      issues.add(
        const WorkflowIssue(
          'workflow_editor.validate_connect_steps',
          'Todos los pasos deben estar conectados entre sí',
        ),
      );
    } else {
      for (final orphan in orphans) {
        issues.add(
          WorkflowIssue(
            'workflow_editor.validate_step_disconnected',
            'El paso {{step}} no está conectado con el resto del flujo',
            nodeId: orphan.id,
            params: {'step': '${steps.indexOf(orphan) + 1}'},
          ),
        );
      }
    }
  }

  final starts = [
    for (final step in steps)
      if (incoming[step.id] == 0) step,
  ];
  final ends = [
    for (final step in steps)
      if (outgoing[step.id]!.isEmpty) step,
  ];

  // Sin inicio o sin final ⇒ todo el grafo es un ciclo; no hay más que decir.
  if (starts.isEmpty || ends.isEmpty) {
    issues.add(
      const WorkflowIssue(
        'workflow_editor.validate_sequence_cycle',
        'La secuencia principal contiene un ciclo',
      ),
    );
    return issues;
  }

  // Único inicio y único final (workflow_validator.py:70-71).
  if (starts.length > 1) {
    for (final step in starts) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_single_start',
          'El paso {{step}} es un segundo inicio: la orquestación debe tener '
              'un único punto de partida',
          nodeId: step.id,
          params: {'step': '${steps.indexOf(step) + 1}'},
        ),
      );
    }
  }
  if (ends.length > 1) {
    for (final step in ends) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_single_end',
          'El paso {{step}} es un segundo final: la orquestación debe tener '
              'un único punto de salida',
          nodeId: step.id,
          params: {'step': '${steps.indexOf(step) + 1}'},
        ),
      );
    }
  }

  final ordered = topologicalOrder(steps);
  if (ordered == null) {
    issues.add(
      const WorkflowIssue(
        'workflow_editor.validate_cycle_or_orphan',
        'El flujo principal contiene un ciclo o pasos desconectados',
      ),
    );
    return issues;
  }

  // ── Ciclos ───────────────────────────────────────────────────────────────
  final indexes = {for (var i = 0; i < ordered.length; i++) ordered[i]: i};
  final intervals = <(int, int)>[];
  for (final step in steps) {
    final target = step.loopTargetId;
    if (target == null) continue;
    final position = '${steps.indexOf(step) + 1}';
    if (target == step.id || !ids.contains(target)) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_loop_target',
          'El ciclo del paso {{step}} apunta a un paso que no existe',
          nodeId: step.id,
          params: {'step': position},
        ),
      );
      continue;
    }
    final start = indexes[target]!;
    final end = indexes[step.id]!;
    // Un ciclo debe volver a un paso anterior (workflow_validator.py:211-214).
    if (start >= end || !_hasPath(target, step.id, outgoing)) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_loop_backwards',
          'El ciclo del paso {{step}} debe volver a un paso anterior del flujo',
          nodeId: step.id,
          params: {'step': position},
        ),
      );
      continue;
    }
    // Los ciclos no pueden solaparse ni anidarse
    // (workflow_validator.py:219-223).
    if (intervals.any((other) => !(end < other.$1 || start > other.$2))) {
      issues.add(
        WorkflowIssue(
          'workflow_editor.validate_loops_overlap',
          'El ciclo del paso {{step}} se solapa o anida con otro ciclo',
          nodeId: step.id,
          params: {'step': position},
        ),
      );
      continue;
    }
    intervals.add((start, end));
  }

  return issues;
}
