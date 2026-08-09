class WorkflowRun {
  const WorkflowRun({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id']?.toString() ?? '';
  String get workflowId => raw['workflow_id']?.toString() ?? '';
  String get workflowName => raw['workflow_name']?.toString() ?? workflowId;
  String get status => raw['status']?.toString() ?? 'queued';
  String? get error => raw['error']?.toString();
  String? get finalOutput => raw['final_output']?.toString();
  int get lastSequence => (raw['last_sequence'] as num?)?.toInt() ?? 0;
  DateTime? get createdAt =>
      DateTime.tryParse(raw['created_at']?.toString() ?? '');
  DateTime? get finishedAt =>
      DateTime.tryParse(raw['finished_at']?.toString() ?? '');
  bool get active => const {'queued', 'running', 'cancelling'}.contains(status);
  bool get cancelling => status == 'cancelling';

  Map<String, dynamic> get definition =>
      (raw['definition'] as Map?)?.cast<String, dynamic>() ?? const {};
  List<Map<String, dynamic>> get agents =>
      (raw['agents'] as List?)
          ?.whereType<Map>()
          .map((value) => value.cast<String, dynamic>())
          .toList() ??
      const [];

  Map<String, dynamic> get progress =>
      (raw['progress'] as Map?)?.cast<String, dynamic>() ?? const {};
  int get completedSteps => (progress['completed'] as num?)?.toInt() ?? 0;
  int get totalSteps => (progress['total'] as num?)?.toInt() ?? 0;
}
