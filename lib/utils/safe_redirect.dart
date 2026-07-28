import '../app/router/route_names.dart';

String safeRedirect(String? raw) {
  if (raw == null || raw.isEmpty) return RouteNames.dashboard;
  if (!raw.startsWith('/')) return RouteNames.dashboard;
  if (raw.startsWith('//')) return RouteNames.dashboard;
  if (raw.startsWith(RouteNames.login)) return RouteNames.dashboard;
  return raw;
}
