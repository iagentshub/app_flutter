import '../common/resource_item.dart';

class ToolItem extends ResourceItem {
  const ToolItem({required super.raw});

  String get language => raw['language'] as String? ?? '';
  String get content => raw['content'] as String? ?? '';

  /// Metadatos ligeros del binario (solo tools `cpp`) — el propio binario
  /// (`binary_b64`) nunca viaja en listado ni en get, ver `tools.py`.
  String? get binaryFilename => raw['binary_filename'] as String?;
  int? get binarySize => (raw['binary_size'] as num?)?.toInt();
  String? get binaryUploadedAt => raw['binary_uploaded_at'] as String?;

  bool get hasBinary => (binaryFilename ?? '').isNotEmpty;
}
