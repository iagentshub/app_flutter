import '../common/resource_item.dart';

class SkillItem extends ResourceItem {
  const SkillItem({required super.raw});

  String get category => raw['category'] as String? ?? '';
  String get content => raw['content'] as String? ?? '';
}
