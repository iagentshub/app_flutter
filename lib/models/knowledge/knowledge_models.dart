import '../../utils/i18n.dart';
import '../common/resource_item.dart';

class KnowledgeItem extends ResourceItem {
  const KnowledgeItem({required super.raw});

  String get type => raw['type'] as String? ?? 'text';

  /// El backend expone `name` (canónico) y `title` (compat). Preferimos `name`
  /// y caemos a `title` para respuestas antiguas.
  @override
  String get name =>
      raw['name'] as String? ??
      raw['title'] as String? ??
      tr('common.untitled');

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

  int get charCount => _asInt(raw['char_count']);

  /// Caracteres que tenía el original antes de que el backend acotara la
  /// extracción. Solo difiere de [charCount] cuando [contentTruncated].
  int get sourceCharCount {
    final total = _asInt(raw['source_char_count']);
    return total > 0 ? total : charCount;
  }

  /// Si el documento entró a medias. Hay que enseñarlo: el original no se
  /// guarda en ningún sitio, así que una ficha recortada que se pinta como
  /// completa es indistinguible de una completa, y el usuario le pregunta al
  /// agente por un texto que nunca llegó.
  bool get contentTruncated => raw['content_truncated'] == true;

  /// `max_chars`, `timeout` o `max_download_bytes`.
  String get truncationReason => raw['truncation_reason'] as String? ?? '';

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }
}

class KnowledgePack extends ResourceItem {
  const KnowledgePack({required super.raw});

  @override
  String get name => raw['name'] as String? ?? tr('common.unnamed');
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
