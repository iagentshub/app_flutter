class SkillItem {
  const SkillItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String? ?? '';
  String get name => raw['name'] as String? ?? '(sin nombre)';
  String get description => raw['description'] as String? ?? '';
  String get icon => raw['icon'] as String? ?? '🔧';
  String get category => raw['category'] as String? ?? '';
  String get content => raw['content'] as String? ?? '';
  String get scope => raw['scope'] as String? ?? 'private';
  bool get shared => raw['_shared'] == true;
  bool get readOnly => scope == 'public' || shared;

  List<String> get tags {
    final value = raw['tags'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }

  List<String> get labels {
    final value = raw['labels'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const ['private'];
  }
}
