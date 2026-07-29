class MemoryFileItem {
  const MemoryFileItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String? ?? '';
  String get filename =>
      raw['filename'] as String? ?? '${id.isEmpty ? 'memory' : id}.md';

  int get size {
    final value = raw['size'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String get updatedAt => raw['updated_at'] as String? ?? '';
}
