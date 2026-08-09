import '../common/resource_item.dart';

class PromptItem extends ResourceItem {
  const PromptItem({required super.raw});

  String get alias => raw['alias'] as String? ?? '';
  String get content => raw['content'] as String? ?? '';
}
