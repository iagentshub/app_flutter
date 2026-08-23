class ResourceExecution {
  const ResourceExecution({
    required this.id,
    required this.resourceType,
    required this.resourceId,
    required this.resourceIds,
    required this.status,
    required this.startedAt,
    this.runId,
  });

  factory ResourceExecution.fromJson(Map<String, dynamic> json) {
    return ResourceExecution(
      id: json['execution_id']?.toString() ?? '',
      resourceType: json['resource_type']?.toString() ?? '',
      resourceId: json['resource_id']?.toString() ?? '',
      resourceIds: ((json['resource_ids'] as List?) ?? const [])
          .map((value) => value.toString())
          .toSet(),
      runId: json['run_id']?.toString(),
      status: json['status']?.toString() ?? '',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
    );
  }

  final String id;
  final String resourceType;
  final String resourceId;
  final Set<String> resourceIds;
  final String? runId;
  final String status;
  final DateTime? startedAt;
}
