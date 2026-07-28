class BackendOption {
  const BackendOption({
    required this.id,
    required this.label,
    required this.baseUrl,
    this.editable = false,
  });

  final String id;
  final String label;
  final String baseUrl;
  final bool editable;
}
