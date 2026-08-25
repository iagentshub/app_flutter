import '../../models/tools/tool_models.dart';

/// Runtime catalog advertised by the active backend.
///
/// Presentation remains local (icons and translations), while the server is
/// the source of truth for which values can be created.
abstract final class ToolRuntimeCatalog {
  static const List<ToolLanguage> _defaults = [
    ToolLanguage.python,
    ToolLanguage.shell,
    ToolLanguage.cpp,
  ];
  static const List<String> _defaultTargetOperatingSystems = [
    'linux',
    'macos',
    'windows',
  ];
  static const List<String> _defaultTargetArchitectures = ['x64', 'arm64'];
  static const Map<String, ToolLanguage> _defaultExtensions = {
    '.py': ToolLanguage.python,
    '.sh': ToolLanguage.shell,
    '.cpp': ToolLanguage.cpp,
  };

  static List<ToolLanguage> _supported = _defaults;
  static List<String> _targetOperatingSystems = _defaultTargetOperatingSystems;
  static List<String> _targetArchitectures = _defaultTargetArchitectures;
  static Map<String, ToolLanguage> _extensions = _defaultExtensions;

  static List<ToolLanguage> get supported => List.unmodifiable(_supported);
  static List<String> get targetOperatingSystems =>
      List.unmodifiable(_targetOperatingSystems);
  static List<String> get targetArchitectures =>
      List.unmodifiable(_targetArchitectures);

  static ToolLanguage? fromSourcePath(String path) {
    final normalized = path.toLowerCase();
    for (final entry in _extensions.entries) {
      if (normalized.endsWith(entry.key)) return entry.value;
    }
    return null;
  }

  static String? scriptExtension(ToolLanguage language) {
    for (final entry in _extensions.entries) {
      if (entry.value == language && !language.requiresBinary) {
        return entry.key.replaceFirst('.', '');
      }
    }
    return null;
  }

  static void updateFromPlatform(Map<String, dynamic> platform) {
    // Cada respuesta pertenece al backend activo. Restablecer antes de leerla
    // evita conservar el catálogo de una sesión/servidor anterior.
    _supported = _defaults;
    _targetOperatingSystems = _defaultTargetOperatingSystems;
    _targetArchitectures = _defaultTargetArchitectures;
    _extensions = _defaultExtensions;
    final raw = platform['tool_runtimes'];
    if (raw is! List) return;
    final next = <ToolLanguage>[];
    final nextExtensions = <String, ToolLanguage>{};
    for (final item in raw) {
      final value = item is Map ? item['api_value'] : item;
      final runtime = ToolLanguage.tryParseSupported(value);
      if (runtime != null && !next.contains(runtime)) next.add(runtime);
      if (runtime != null && item is Map && item['extensions'] is List) {
        for (final rawExtension in item['extensions'] as List) {
          final extension = rawExtension.toString().trim().toLowerCase();
          if (extension.startsWith('.') && extension.length > 1) {
            nextExtensions[extension] = runtime;
          }
        }
      }
      if (runtime == ToolLanguage.cpp && item is Map) {
        final operatingSystems = item['target_operating_systems'];
        final architectures = item['target_architectures'];
        if (operatingSystems is List && operatingSystems.isNotEmpty) {
          _targetOperatingSystems = operatingSystems
              .map((value) => value.toString())
              .toList(growable: false);
        }
        if (architectures is List && architectures.isNotEmpty) {
          _targetArchitectures = architectures
              .map((value) => value.toString())
              .toList(growable: false);
        }
      }
    }
    if (next.isNotEmpty) {
      _supported = next;
      _extensions = nextExtensions;
    }
  }
}
