class DashboardSummary {
  const DashboardSummary({
    required this.agents,
    required this.connections,
    required this.knowledge,
    required this.workflows,
  });

  final int agents;
  final int connections;
  final int knowledge;
  final int workflows;
}
