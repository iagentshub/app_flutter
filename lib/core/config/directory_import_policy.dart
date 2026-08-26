import '../../shared/state/upload_limits.dart';

enum DirectoryImportKind { knowledgePack, agent }

/// Política local de seguridad y rendimiento para importar directorios.
///
/// No es configuración administrable: evita subir metadatos, dependencias,
/// artefactos generados y posibles secretos. El backend vuelve a validar todo;
/// este filtro evita leer y transferir contenido descartable desde el cliente.
abstract final class DirectoryImportPolicy {
  static const Set<String> _ignoredDirectoryNames = {
    '.git',
    '.svn',
    '.hg',
    'node_modules',
    'build',
    'dist',
    '.dart_tool',
    '.idea',
    '.vscode',
    '__pycache__',
    '.pytest_cache',
    '.mypy_cache',
  };

  static const Set<String> _secretFileNames = {
    'id_rsa',
    'id_dsa',
    'id_ecdsa',
    'id_ed25519',
    'credentials',
    'credentials.json',
    'secrets.json',
  };

  static Set<String> ignoredDirectoryNames(DirectoryImportKind kind) =>
      switch (kind) {
        DirectoryImportKind.knowledgePack => _ignoredDirectoryNames,
        DirectoryImportKind.agent => _ignoredDirectoryNames,
      };

  static bool ignoresDirectory(DirectoryImportKind kind, String name) =>
      ignoredDirectoryNames(kind).contains(name.toLowerCase());

  static bool supportsPath(DirectoryImportKind kind, String path) {
    final normalized = path.replaceAll(r'\', '/').toLowerCase();
    final parts = normalized
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty ||
        parts
            .take(parts.length - 1)
            .any(ignoredDirectoryNames(kind).contains)) {
      return false;
    }
    final name = parts.last;
    if (name == '.env' ||
        (name.startsWith('.env.') && name != '.env.example') ||
        _secretFileNames.contains(name) ||
        name.endsWith('.pem') ||
        name.endsWith('.key') ||
        name.endsWith('.p12') ||
        name.endsWith('.pfx')) {
      return false;
    }
    return true;
  }

  static bool exceedsUploadLimit(int bytes) => UploadLimits.exceeds(bytes);
}
