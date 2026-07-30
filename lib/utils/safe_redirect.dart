import '../app/router/route_names.dart';

String safeRedirect(String? raw) {
  if (raw == null || raw.isEmpty || raw != raw.trim()) {
    return RouteNames.dashboard;
  }
  if (raw.contains(r'\') || raw.codeUnits.any((code) => code < 0x20)) {
    return RouteNames.dashboard;
  }

  final uri = Uri.tryParse(raw);
  if (uri == null ||
      uri.isAbsolute ||
      uri.hasAuthority ||
      !uri.path.startsWith('/')) {
    return RouteNames.dashboard;
  }

  String decodedPath;
  try {
    decodedPath = Uri.decodeComponent(uri.path);
  } on FormatException {
    return RouteNames.dashboard;
  }
  if (decodedPath.startsWith('//') ||
      decodedPath.contains(r'\') ||
      decodedPath.codeUnits.any((code) => code < 0x20)) {
    return RouteNames.dashboard;
  }
  if (decodedPath == RouteNames.login ||
      decodedPath.startsWith('${RouteNames.login}/')) {
    return RouteNames.dashboard;
  }
  return uri.toString();
}
