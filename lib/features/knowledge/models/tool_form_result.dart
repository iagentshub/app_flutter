final class PendingToolArtifact {
  const PendingToolArtifact({
    required this.fileName,
    required this.size,
    required this.openRead,
  });

  final String fileName;
  final int size;
  final Stream<List<int>> Function() openRead;
}

final class ToolFormResult {
  const ToolFormResult({required this.payload, this.artifact});

  final Map<String, dynamic> payload;
  final PendingToolArtifact? artifact;
}
