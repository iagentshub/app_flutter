import '../common/resource_item.dart';

class KnowledgeItem extends ResourceItem {
  const KnowledgeItem({required super.raw});

  String get type => raw['type'] as String? ?? 'text';

  /// El backend expone `name` (canónico) y `title` (compat). Preferimos `name`
  /// y caemos a `title` para respuestas antiguas.
  @override
  String get name =>
      raw['name'] as String? ?? raw['title'] as String? ?? '(sin título)';

  /// Alias histórico usado por la UI de conocimiento.
  String get title => name;

  String get source => raw['source'] as String? ?? '';
  String get preview => raw['content'] as String? ?? '';

  int get charCount {
    final value = raw['char_count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}
