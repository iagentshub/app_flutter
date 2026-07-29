class ResourceVersionItem {
  const ResourceVersionItem({required this.raw});

  final Map<String, dynamic> raw;

  int get version => (raw['version'] as num?)?.toInt() ?? 0;
  String get createdBy => raw['created_by'] as String? ?? '';
  String get reason => raw['reason'] as String? ?? 'save';
  String get createdAt => raw['created_at'] as String? ?? '';

  /// true si esta versión es el resultado de restaurar una anterior
  /// (`reason` viene como `restore:{version}`).
  bool get isRestore => reason.startsWith('restore:');
}
