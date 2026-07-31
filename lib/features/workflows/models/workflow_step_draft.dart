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

  /// IDs de los pasos siguientes; varios destinos representan ramas
  /// paralelas y un destino compartido representa fan-in.
  List<String> nextStepIds;
}
