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
  String? get packId => raw['pack_id'] as String?;
  String get packRelativePath => raw['pack_relative_path'] as String? ?? '';
  String get packKind => raw['pack_kind'] as String? ?? '';
  String get mimeType => raw['mime_type'] as String? ?? '';
  int get sizeBytes => (raw['size_bytes'] as num?)?.toInt() ?? 0;

  bool get isImage {
    if (packKind == 'image' || mimeType.startsWith('image/')) return true;
    final lower = source.toLowerCase();
    return const [
      '.png',
      '.jpg',
      '.jpeg',
      '.webp',
      '.bmp',
      '.tif',
      '.tiff',
      '.heic',
      '.heif',
    ].any(lower.endsWith);
  }

  int get charCount {
    final value = raw['char_count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class KnowledgePack extends ResourceItem {
  const KnowledgePack({required super.raw});

  @override
  String get name => raw['name'] as String? ?? '(sin nombre)';
  @override
  String get description => raw['description'] as String? ?? '';
  int get fileCount => (raw['file_count'] as num?)?.toInt() ?? 0;
  int get sizeBytes => (raw['size_bytes'] as num?)?.toInt() ?? 0;
  int get ignoredCount => (raw['ignored'] as List?)?.length ?? 0;
  String get sourceMode =>
      raw['source_mode'] == 'reference' ? 'reference' : 'upload';
  String get lastSyncedAt => raw['last_synced_at'] as String? ?? '';
  bool get canSynchronize => true;
  List<Map<String, dynamic>> get items => (raw['items'] as List? ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
}
