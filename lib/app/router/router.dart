import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../features/dashboard/repositories/dashboard_repository.dart';
import '../../features/public/pages/not_found_page.dart';
import '../../shared/state/backend_controller.dart';
import '../../shared/state/dashboard_edit_state.dart';
import '../../shared/state/locale_controller.dart';
import '../../shared/state/session_controller.dart';
import '../../shared/widgets/terminal_view_transition.dart';
import '../../utils/safe_redirect.dart';
import 'external_router.dart';
import 'internal_router.dart';

/// Punto único del router de la app: construye el [GoRouter] combinando las
/// rutas de [externalRoutes] y [buildShellRoute], y expone las funciones de
/// navegación (`toX`) que el resto del código debe usar para desplazarse en
/// vez de llamar a `context.go`/`context.push` con paths sueltos.
abstract final class AppRouter {
  static GoRouter create({
    required BackendController backendController,
    required SessionController sessionController,
    required LocaleController localeController,
    required AuthRepository authRepository,
    required DashboardRepository dashboardRepository,
    required ApiClient apiClient,
    required DashboardEditState dashboardEditState,
  }) {
    final shellNavigatorKey = GlobalKey<NavigatorState>();

    bool isPublicPath(String path) {
      const publicPaths = {
        ExternalRoutes.home,
        ExternalRoutes.login,
        ExternalRoutes.register,
        ExternalRoutes.forgotPassword,
        ExternalRoutes.resetPassword,
        ExternalRoutes.verify,
        ExternalRoutes.backendConfig,
      };
      return publicPaths.contains(path);
    }

    return GoRouter(
      initialLocation: ExternalRoutes.login,
      refreshListenable: sessionController,
      errorBuilder: (context, state) =>
          const TerminalViewTransition(child: NotFoundPage()),
      redirect: (context, state) {
        final location = state.matchedLocation;
        final public = isPublicPath(location);

        if (!sessionController.isLoggedIn && !public) {
          final redirect = Uri.encodeComponent(state.uri.toString());
          return '${ExternalRoutes.login}?redirect=$redirect';
        }

        if (sessionController.isLoggedIn &&
            (location == ExternalRoutes.login ||
                location == ExternalRoutes.home)) {
          return safeRedirect(state.uri.queryParameters['redirect']);
        }

        final isAdminRoute = location.startsWith(InternalRoutes.admin);
        final isAdmin = sessionController.user?.role == 'admin';
        if (isAdminRoute && !isAdmin) return InternalRoutes.dashboard;

        return null;
      },
      routes: [
        ...externalRoutes(
          backendController: backendController,
          sessionController: sessionController,
          localeController: localeController,
          authRepository: authRepository,
        ),
        buildShellRoute(
          shellNavigatorKey: shellNavigatorKey,
          backendController: backendController,
          sessionController: sessionController,
          authRepository: authRepository,
          dashboardRepository: dashboardRepository,
          apiClient: apiClient,
          dashboardEditState: dashboardEditState,
          localeController: localeController,
        ),
      ],
    );
  }

  // --- Navegación externa (marketing público y auth) ---

  static void toLogin(BuildContext context) =>
      context.go(ExternalRoutes.login);

  static void toRegister(BuildContext context) =>
      context.go(ExternalRoutes.register);

  static void toForgotPassword(BuildContext context) =>
      context.go(ExternalRoutes.forgotPassword);

  static void toHome(BuildContext context, {bool english = false}) =>
      context.go(english ? ExternalRoutes.homeEn : ExternalRoutes.home);

  static Future<void> toBackendConfig(BuildContext context) =>
      context.push(ExternalRoutes.backendConfig);

  // --- Navegación interna (dentro del shell autenticado) ---

  static void toDashboard(BuildContext context) =>
      context.go(InternalRoutes.dashboard);

  static void toAgents(BuildContext context) =>
      context.go(InternalRoutes.agents);

  static void toManager(BuildContext context) =>
      context.go(InternalRoutes.manager);

  static void toProfile(BuildContext context) =>
      context.go(InternalRoutes.profile);

  static void toProfileBilling(BuildContext context) =>
      context.go('${InternalRoutes.profile}?section=billing');

  static Future<void> toPublicProfile(BuildContext context, String username) =>
      context.push('${InternalRoutes.publicProfilePrefix}$username');

  // --- Navegación genérica: destinos resueltos en tiempo de ejecución ---
  // (listas de datos con su propia ruta, redirects calculados, etc.)

  static void go(BuildContext context, String path) => context.go(path);

  static Future<void> push(BuildContext context, String path) =>
      context.push(path);
}
