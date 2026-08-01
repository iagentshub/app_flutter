import '../common/resource_item.dart';

class SkillItem extends ResourceItem {
  const SkillItem({required super.raw});

  String get category => raw['category'] as String? ?? '';
  String get content => raw['content'] as String? ?? '';

  List<String> get tags {
    final value = raw['tags'];
    if (value is List) return value.map((item) => item.toString()).toList();
    return const [];
  }
}
