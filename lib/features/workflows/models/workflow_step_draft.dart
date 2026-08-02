class WorkflowStepDraft {
  WorkflowStepDraft({
    required this.id,
    this.agentId = '',
    this.label = '',
    this.instruction = '',
    this.kind = 'agent',
    this.evaluatorCondition = '',
    this.evaluatorMaxIterations = 5,
    this.loopTargetId,
    this.loopIterations = 2,
    this.positionX,
    this.positionY,
    List<String>? nextStepIds,
  }) : nextStepIds = nextStepIds ?? [];

  final String id;
  String agentId;
  String label;
  String instruction;
  String kind;
  String evaluatorCondition;
  int evaluatorMaxIterations;
  String? loopTargetId;
  int loopIterations;
  double? positionX;
  double? positionY;

  /// IDs de los pasos siguientes; varios destinos representan ramas
  /// paralelas y un destino compartido representa fan-in.
  List<String> nextStepIds;

  bool get isEvaluator => kind == 'evaluator';
}

extension WorkflowStepDraftCollection on Iterable<WorkflowStepDraft> {
  int get connectionCount => fold(
    0,
    (total, step) =>
        total + step.nextStepIds.length + (step.loopTargetId == null ? 0 : 1),
  );

  WorkflowStepDraft? byId(String id) {
    for (final step in this) {
      if (step.id == id) return step;
    }
    return null;
  }
}

/// Convierte el `definition` que guarda el backend en borradores editables.
///
/// Compartida por el editor y por el visor de ejecución en vivo: ambos parten
/// del mismo `{nodes, edges}` y necesitan el mismo grafo.
List<WorkflowStepDraft> stepsFromDefinition(Map<String, dynamic> definition) {
  final nodes = (definition['nodes'] as List? ?? [])
      .whereType<Map>()
      .map((node) => Map<String, dynamic>.from(node))
      .toList();
  final edges = (definition['edges'] as List? ?? [])
      .whereType<Map>()
      .map((edge) => Map<String, dynamic>.from(edge))
      .toList();
  if (nodes.isEmpty) return [];

  final sequenceEdges = edges
      .where((e) => (e['type'] ?? 'sequence') == 'sequence')
      .toList();
  final loopEdges = edges.where((e) => e['type'] == 'loop').toList();

  return nodes.map((n) {
    final id = n['id'].toString();
    final loop = loopEdges.where((e) => e['source']?.toString() == id).toList();
    final evaluator = n['evaluator'] as Map?;
    final nextIds = sequenceEdges
        .where((e) => e['source']?.toString() == id)
        .map((e) => e['target'].toString())
        .toList();
    return WorkflowStepDraft(
      id: id,
      agentId: n['agent_id']?.toString() ?? '',
      label: n['label']?.toString() ?? '',
      instruction: n['instruction']?.toString() ?? '',
      kind: n['kind']?.toString() ?? 'agent',
      evaluatorCondition: evaluator?['condition']?.toString() ?? '',
      evaluatorMaxIterations:
          (evaluator?['max_iterations'] as num?)?.toInt() ?? 5,
      loopTargetId: loop.isEmpty ? null : loop.first['target']?.toString(),
      loopIterations: loop.isEmpty
          ? 2
          : ((loop.first['iterations'] as num?)?.toInt() ?? 2),
      positionX: ((n['position'] as Map?)?['x'] as num?)?.toDouble(),
      positionY: ((n['position'] as Map?)?['y'] as num?)?.toDouble(),
      nextStepIds: nextIds,
    );
  }).toList();
}

/// Serializa los borradores al `definition` que espera
/// `backend/app/services/workflow_validator.py`.
Map<String, dynamic> buildDefinition(List<WorkflowStepDraft> steps) {
  final nodes = steps.map((step) {
    final node = <String, dynamic>{
      'id': step.id,
      'agent_id': step.agentId,
      'label': step.label,
      'instruction': step.instruction,
      'kind': step.kind,
      if (step.positionX != null && step.positionY != null)
        'position': {'x': step.positionX, 'y': step.positionY},
    };
    if (step.isEvaluator) {
      node['evaluator'] = {
        'condition': step.evaluatorCondition,
        'max_iterations': step.evaluatorMaxIterations,
      };
    }
    return node;
  }).toList();

  final edges = <Map<String, dynamic>>[];
  for (final step in steps) {
    for (final nextId in step.nextStepIds) {
      edges.add({'source': step.id, 'target': nextId, 'type': 'sequence'});
    }
  }
  for (final step in steps) {
    final loopTargetId = step.loopTargetId;
    if (loopTargetId == null) continue;
    final edge = <String, dynamic>{
      'source': step.id,
      'target': loopTargetId,
      'type': 'loop',
      'mode': step.isEvaluator ? 'condition' : 'fixed',
    };
    if (!step.isEvaluator) edge['iterations'] = step.loopIterations;
    edges.add(edge);
  }

  return {'nodes': nodes, 'edges': edges};
}
