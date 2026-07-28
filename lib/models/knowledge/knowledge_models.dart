class KnowledgeItem {
  const KnowledgeItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String? ?? '';
  String get type => raw['type'] as String? ?? 'text';
  String get title => raw['title'] as String? ?? '(sin título)';
  String get source => raw['source'] as String? ?? '';
  int get charCount {
    final value = raw['char_count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String get updatedAt => raw['updated_at'] as String? ?? '';
  String get preview => raw['content'] as String? ?? '';
  bool get shared => raw['_shared'] == true;
}
