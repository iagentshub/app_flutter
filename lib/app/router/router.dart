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
    required VoidCallback onRetrySession,
    required VoidCallback onUseAnotherAccount,
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
        ExternalRoutes.sessionRestore,
        ExternalRoutes.sessionUnavailable,
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
        final status = sessionController.status;
        final recoveryRoute =
            location == ExternalRoutes.sessionRestore ||
            location == ExternalRoutes.sessionUnavailable;
        final canBypassRecovery =
            location == ExternalRoutes.backendConfig ||
            location == ExternalRoutes.register ||
            location == ExternalRoutes.forgotPassword ||
            location == ExternalRoutes.resetPassword ||
            location == ExternalRoutes.verify;

        String recoveryRedirect(String route) {
          final requested =
              location == ExternalRoutes.login ||
                  location == ExternalRoutes.home ||
                  recoveryRoute
              ? safeRedirect(state.uri.queryParameters['redirect'])
              : state.uri.toString();
          return '$route?redirect=${Uri.encodeComponent(requested)}';
        }

        if (status == SessionStatus.restoring && !canBypassRecovery) {
          if (location == ExternalRoutes.sessionRestore) return null;
          return recoveryRedirect(ExternalRoutes.sessionRestore);
        }

        if (status == SessionStatus.backendUnavailable && !canBypassRecovery) {
          if (location == ExternalRoutes.sessionUnavailable) return null;
          return recoveryRedirect(ExternalRoutes.sessionUnavailable);
        }

        if (status == SessionStatus.signedOut && recoveryRoute) {
          return ExternalRoutes.login;
        }

        if (!sessionController.isLoggedIn && !public) {
          final redirect = Uri.encodeComponent(state.uri.toString());
          return '${ExternalRoutes.login}?redirect=$redirect';
        }

        if (sessionController.isLoggedIn &&
            (location == ExternalRoutes.login ||
                location == ExternalRoutes.home ||
                recoveryRoute)) {
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
          onRetrySession: onRetrySession,
          onUseAnotherAccount: onUseAnotherAccount,
        ),
        buildShellRoute(
          shellNavigatorKey: shellNavigatorKey,
          backendController: backendController,
          authRepository: authRepository,
          dashboardRepository: dashboardRepository,
          dashboardEditState: dashboardEditState,
        ),
      ],
    );
  }

  // --- Navegación externa (marketing público y auth) ---

  static void toLogin(BuildContext context) => context.go(ExternalRoutes.login);

  static void toRegister(BuildContext context) =>
      context.go(ExternalRoutes.register);

  static void toForgotPassword(BuildContext context) =>
      context.go(ExternalRoutes.forgotPassword);

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
