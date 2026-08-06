import '../app/router/external_router.dart';
import '../app/router/internal_router.dart';

String safeRedirect(String? raw) {
  if (raw == null || raw.isEmpty || raw != raw.trim()) {
    return InternalRoutes.dashboard;
  }
  if (raw.contains(r'\') || raw.codeUnits.any((code) => code < 0x20)) {
    return InternalRoutes.dashboard;
  }

  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.isAbsolute ||
      uri.hasAuthority ||
      !uri.path.startsWith('/')) {
    return InternalRoutes.dashboard;
  }

  String decodedPath;
  try {
    decodedPath = Uri.decodeComponent(uri.path);
  } on FormatException {
    return InternalRoutes.dashboard;
  }
  if (decodedPath.startsWith('//') ||
      decodedPath.contains(r'\') ||
      decodedPath.codeUnits.any((code) => code < 0x20)) {
    return InternalRoutes.dashboard;
  }
  if (decodedPath == ExternalRoutes.login ||
      decodedPath.startsWith('${ExternalRoutes.login}/')) {
    return InternalRoutes.dashboard;
  }
  return uri.toString();
}
