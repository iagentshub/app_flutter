import '../common/resource_item.dart';

class PromptItem extends ResourceItem {
  const PromptItem({required super.raw});

  String get alias => raw['alias'] as String? ?? '';
  String get content => raw['content'] as String? ?? '';

  @override
  bool get readOnly =>
      shared || (scope == 'public' && raw['origin_type'] != 'owner');
}
