class GroupItem {
  const GroupItem({required this.raw});

  final Map<String, dynamic> raw;

  String get id => raw['id'] as String? ?? '';
  String get name => raw['name'] as String? ?? '(sin nombre)';
  String get type => raw['type'] as String? ?? 'team';
  String get role => raw['role'] as String? ?? 'member';
  bool get active => raw['active'] == true;

  bool get isPersonal => type == 'personal';
}
