import 'package:go_router/go_router.dart';

import '../../features/auth/pages/backend_config_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/reset_password_page.dart';
import '../../features/auth/pages/verify_page.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../shared/state/backend_controller.dart';
import '../../shared/state/locale_controller.dart';
import '../../shared/state/session_controller.dart';
import '../../shared/widgets/terminal_view_transition.dart';

/// Rutas accesibles sin sesión: marketing público y flujo de autenticación.
abstract final class ExternalRoutes {
  static const home = '/';
  static const homeEn = '/en';
  static const about = '/about';
  static const aboutEn = '/en/about';
  static const docs = '/docs';
  static const docsEn = '/en/docs';
  static const support = '/support';
  static const supportEn = '/en/support';
  static const pricing = '/pricing';
  static const pricingEn = '/en/pricing';

  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verify = '/verify';
  static const backendConfig = '/backend';
}

/// Sitio público real (marketing), fuera de esta app Flutter.
const publicSiteBaseUrl = 'https://www.iagentshub.com';

/// Resuelve una URL hacia [publicSiteBaseUrl], o hacia el propio origen del
/// navegador cuando la app y el marketing comparten dominio en producción.
Uri resolvePublicSiteUri({
  required String path,
  required bool useSameOrigin,
  Uri? browserBase,
}) {
  final normalizedPath = path.startsWith('/') ? path : '/$path';
  if (useSameOrigin) {
    return (browserBase ?? Uri.base).resolve(normalizedPath);
  }
  return Uri.parse('$publicSiteBaseUrl$normalizedPath');
}

/// Rutas top-level (fuera del [ShellRoute]) para marketing público y auth.
List<RouteBase> externalRoutes({
  required BackendController backendController,
  required SessionController sessionController,
  required LocaleController localeController,
  required AuthRepository authRepository,
}) {
  return [
    GoRoute(
      path: ExternalRoutes.home,
      redirect: (context, state) => ExternalRoutes.login,
    ),
    for (final path in const [
      ExternalRoutes.homeEn,
      ExternalRoutes.about,
      ExternalRoutes.aboutEn,
      ExternalRoutes.docs,
      ExternalRoutes.docsEn,
      ExternalRoutes.support,
      ExternalRoutes.supportEn,
      ExternalRoutes.pricing,
      ExternalRoutes.pricingEn,
    ])
      GoRoute(path: path, redirect: (context, state) => ExternalRoutes.home),
    GoRoute(
      path: ExternalRoutes.login,
      builder: (context, state) => TerminalViewTransition(
        child: LoginPage(
          backendController: backendController,
          sessionController: sessionController,
          localeController: localeController,
          authRepository: authRepository,
          redirectTo: state.uri.queryParameters['redirect'],
        ),
      ),
    ),
    GoRoute(
      path: ExternalRoutes.register,
      builder: (context, state) => TerminalViewTransition(
        child: RegisterPage(
          authRepository: authRepository,
          localeController: localeController,
        ),
      ),
    ),
    GoRoute(
      path: ExternalRoutes.forgotPassword,
      builder: (context, state) => TerminalViewTransition(
        child: ForgotPasswordPage(
          authRepository: authRepository,
          localeController: localeController,
        ),
      ),
    ),
    GoRoute(
      path: ExternalRoutes.resetPassword,
      builder: (context, state) => TerminalViewTransition(
        child: ResetPasswordPage(
          authRepository: authRepository,
          localeController: localeController,
          token: state.uri.queryParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: ExternalRoutes.verify,
      builder: (context, state) => TerminalViewTransition(
        child: VerifyPage(
          authRepository: authRepository,
          sessionController: sessionController,
          localeController: localeController,
          token: state.uri.queryParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: ExternalRoutes.backendConfig,
      builder: (context, state) => TerminalViewTransition(
        child: BackendConfigPage(
          backendController: backendController,
          localeController: localeController,
        ),
      ),
    ),
  ];
}
