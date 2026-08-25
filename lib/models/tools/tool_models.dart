import 'package:flutter/material.dart';

import '../common/resource_item.dart';

/// Contrato y presentación de un runtime de Tool.
///
/// Las instancias conocidas son canónicas; una desconocida conserva siempre el
/// valor recibido para no convertir silenciosamente un código futuro en `''`.
final class ToolLanguage {
  const ToolLanguage._(
    this.apiValue,
    this.translationKey,
    this.icon,
    this.requiresBinary,
  );

  const ToolLanguage._unknown(this.apiValue)
    : translationKey = '',
      icon = Icons.build_outlined,
      requiresBinary = false;

  static const python = ToolLanguage._(
    'python',
    'tools.language_python',
    Icons.code,
    false,
  );
  static const shell = ToolLanguage._(
    'shell',
    'tools.language_shell',
    Icons.terminal,
    false,
  );
  static const cpp = ToolLanguage._(
    'cpp',
    'tools.language_cpp',
    Icons.memory,
    true,
  );
  static const unknown = ToolLanguage._unknown('');

  final String apiValue;
  final String translationKey;
  final IconData icon;
  final bool requiresBinary;

  bool get isSupported => translationKey.isNotEmpty;

  static ToolLanguage fromApi(Object? value) {
    final code = value?.toString() ?? '';
    return tryParseSupported(code) ?? ToolLanguage._unknown(code);
  }

  static ToolLanguage? tryParseSupported(Object? value) => switch (value) {
    'python' => python,
    'shell' => shell,
    'cpp' => cpp,
    _ => null,
  };

  String label(String Function(String path) tx, {String? fallback}) =>
      isSupported ? tx(translationKey) : (fallback ?? apiValue);

  @override
  bool operator ==(Object other) =>
      other is ToolLanguage && other.apiValue == apiValue;

  @override
  int get hashCode => apiValue.hashCode;
}

class ToolItem extends ResourceItem {
  const ToolItem({required super.raw});

  String get languageValue => raw['language'] as String? ?? '';
  ToolLanguage get language => ToolLanguage.fromApi(languageValue);
  String languageLabel(String Function(String path) tx) =>
      language.label(tx, fallback: languageValue);
  String get content => raw['content'] as String? ?? '';
  String get instructions => raw['instructions'] as String? ?? '';
  bool get isReady =>
      raw['ready'] as bool? ??
      (language.requiresBinary ? hasBinary : content.isNotEmpty);
  Map<String, dynamic> get inputSchema =>
      (raw['input_schema'] as Map?)?.cast<String, dynamic>() ?? const {};
  Map<String, dynamic> get outputSchema =>
      (raw['output_schema'] as Map?)?.cast<String, dynamic>() ?? const {};
  String get targetOs => raw['target_os'] as String? ?? '';
  String get targetArch => raw['target_arch'] as String? ?? '';

  /// Metadatos ligeros del binario (solo tools `cpp`) — el propio binario
  /// (`binary_b64`) nunca viaja en listado ni en get, ver `tools.py`.
  String? get binaryFilename => raw['binary_filename'] as String?;
  int? get binarySize => (raw['binary_size'] as num?)?.toInt();
  String? get binaryUploadedAt => raw['binary_uploaded_at'] as String?;
  String get binarySha256 => raw['binary_sha256'] as String? ?? '';
  String get binaryUploadedBy => raw['binary_uploaded_by'] as String? ?? '';

  bool get hasBinary => (binaryFilename ?? '').isNotEmpty;
}
