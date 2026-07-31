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
}

extension WorkflowStepDraftCollection on Iterable<WorkflowStepDraft> {
  int get connectionCount => fold(
    0,
    (total, step) =>
        total + step.nextStepIds.length + (step.loopTargetId == null ? 0 : 1),
  );
}
