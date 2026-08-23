import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/pages/backend_config_page.dart';
import '../../features/auth/pages/forgot_password_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/reset_password_page.dart';
import '../../features/auth/pages/session_recovery_page.dart';
import '../../features/auth/pages/verify_page.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../../shared/state/backend_controller.dart';
import '../../shared/state/locale_controller.dart';
import '../../shared/state/session_controller.dart';
import '../../shared/widgets/motion/app_route_pages.dart';

/// Rutas accesibles sin sesión: marketing público y flujo de autenticación.
abstract final class ExternalRoutes {
  // Rutas del sitio público, en el idioma base. Las demás **no se declaran**:
  // se derivan del código (`/en/docs`, `/fr/docs`) en `publicRoutes`. Antes
  // había una constante por idioma y página —`docs` y `docsEn`, diez en
  // total—, así que añadir un tercer idioma eran cinco constantes más y
  // acordarse de sumarlas a la lista de redirecciones.
  static const publicPaths = [home, about, docs, support, pricing];

  static const home = '/';
  static const about = '/about';
  static const docs = '/docs';
  static const support = '/support';
  static const pricing = '/pricing';

  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';
  static const verify = '/verify';
  static const backendConfig = '/backend';
  static const sessionRestore = '/session/restore';
  static const sessionUnavailable = '/session/unavailable';
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

/// Las rutas públicas en todos los idiomas: `/docs`, `/en/docs`, y las que
/// traiga `supportedLanguageCodes` el día que crezca. El idioma base va sin
/// prefijo, que es como las sirve el sitio público.
List<String> publicPathsPorIdioma() {
  final rutas = <String>[];
  for (final idioma in LocaleController.supportedLanguageCodes) {
    for (final base in ExternalRoutes.publicPaths) {
      if (idioma == LocaleController.fallbackLanguageCode) {
        // La raíz del idioma base la declara aparte quien llama.
        if (base != ExternalRoutes.home) rutas.add(base);
      } else {
        rutas.add(base == ExternalRoutes.home ? '/$idioma' : '/$idioma$base');
      }
    }
  }
  return rutas;
}

/// Rutas top-level (fuera del [ShellRoute]) para marketing público y auth.
List<RouteBase> externalRoutes({
  required BackendController backendController,
  required SessionController sessionController,
  required LocaleController localeController,
  required AuthRepository authRepository,
  required VoidCallback onRetrySession,
  required VoidCallback onUseAnotherAccount,
}) {
  return [
    GoRoute(
      path: ExternalRoutes.home,
      redirect: (context, state) => ExternalRoutes.login,
    ),
    // El sitio público lo sirve React fuera de /app/. Estas rutas existen aquí
    // solo para recoger a quien llegue a ellas dentro de la app y mandarlo a su
    // sitio. Se declaran para el idioma base y para cada idioma soportado, en
    // vez de escribir el par a mano: un idioma nuevo entra solo.
    for (final path in publicPathsPorIdioma())
      GoRoute(path: path, redirect: (context, state) => ExternalRoutes.home),
    GoRoute(
      path: ExternalRoutes.login,
      pageBuilder: (context, state) => fadeThroughPage(
        key: state.pageKey,
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
      pageBuilder: (context, state) => fadeThroughPage(
        key: state.pageKey,
        child: RegisterPage(
          authRepository: authRepository,
          localeController: localeController,
        ),
      ),
    ),
    GoRoute(
      path: ExternalRoutes.forgotPassword,
      pageBuilder: (context, state) => fadeThroughPage(
        key: state.pageKey,
        child: ForgotPasswordPage(
          authRepository: authRepository,
          localeController: localeController,
        ),
      ),
    ),
    GoRoute(
      path: ExternalRoutes.resetPassword,
      pageBuilder: (context, state) => fadeThroughPage(
        key: state.pageKey,
        child: ResetPasswordPage(
          authRepository: authRepository,
          localeController: localeController,
          token: state.uri.queryParameters['token'],
        ),
      ),
    ),
    GoRoute(
      path: ExternalRoutes.verify,
      pageBuilder: (context, state) => fadeThroughPage(
        key: state.pageKey,
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
      pageBuilder: (context, state) => fadeThroughPage(
        key: state.pageKey,
        child: BackendConfigPage(
          backendController: backendController,
          localeController: localeController,
        ),
      ),
    ),
    for (final path in const [
      ExternalRoutes.sessionRestore,
      ExternalRoutes.sessionUnavailable,
    ])
      GoRoute(
        path: path,
        pageBuilder: (context, state) => fadeThroughPage(
          key: state.pageKey,
          child: SessionRecoveryPage(
            sessionController: sessionController,
            backendController: backendController,
            localeController: localeController,
            onRetry: onRetrySession,
            onConfigureBackend: () async {
              await context.push(ExternalRoutes.backendConfig);
              onRetrySession();
            },
            onUseAnotherAccount: onUseAnotherAccount,
          ),
        ),
      ),
  ];
}
