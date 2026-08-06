import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app/app.dart';
import 'core/config/runtime_config.dart';
import 'core/platform/url_strategy.dart';
import 'shared/state/backend_controller.dart';
import 'shared/state/brand_icon_controller.dart';
import 'shared/state/locale_controller.dart';
import 'shared/state/session_controller.dart';
import 'shared/state/theme_controller.dart';
import 'shared/widgets/brand_icon.dart';
import 'shared/widgets/launch_splash.dart';
import 'shared/widgets/terminal_view_transition.dart';

Future<void> main() async {
  configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();
  // El splash (más abajo) monta un MaterialApp normal, que en Flutter Web
  // sincroniza su propia ruta inicial con la barra de direcciones y así
  // pisa cualquier deep link (state/callback del login de VS Code, tokens
  // de verificación/reset, etc.) antes de que exista el GoRouter real.
  // Capturamos la URL original aquí, antes de que nada la toque, para
  // poder restaurarla en App una vez el router de verdad está montado.
  final initialLocation = _captureInitialLocation();
  if (stripePublishableKey.isNotEmpty) {
    Stripe.publishableKey = stripePublishableKey;
    await Stripe.instance.applySettings();
  }
  // Los bootstrap son independientes entre sí (cada uno lee su propia
  // clave de SharedPreferences) — en paralelo en vez de en cadena ahorra
  // esperas de plugin channel en el arranque.
  final results = await Future.wait([
    BackendController.bootstrap(),
    SessionController.bootstrap(),
    LocaleController.bootstrap(),
    BrandIconController.bootstrap(),
    ThemeController.bootstrap(),
  ]);
  final backendController = results[0] as BackendController;
  final sessionController = results[1] as SessionController;
  final localeController = results[2] as LocaleController;
  final brandIconController = results[3] as BrandIconController;
  final themeController = results[4] as ThemeController;

  runApp(
    _BootApp(
      backendController: backendController,
      sessionController: sessionController,
      localeController: localeController,
      brandIconController: brandIconController,
      themeController: themeController,
      initialLocation: initialLocation,
    ),
  );
}

/// Ruta (path + query) de la URL con la que cargó la pestaña, relativa al
/// `<base href="/app/">` del index.html — el mismo espacio de rutas que usa
/// GoRouter. `null` fuera de la web o si la URL no cuelga de `/app`.
String? _captureInitialLocation() {
  if (!kIsWeb) return null;
  const base = '/app';
  final uri = Uri.base;
  String path;
  if (uri.path == base) {
    path = '/';
  } else if (uri.path.startsWith('$base/')) {
    path = uri.path.substring(base.length);
  } else {
    return null;
  }
  final location = Uri(
    path: path,
    query: uri.query.isEmpty ? null : uri.query,
    fragment: uri.fragment.isEmpty ? null : uri.fragment,
  ).toString();
  // "/" es el destino por defecto de todas formas — no merece la pena
  // forzar una navegación explícita para él.
  return location == '/' ? null : location;
}

class _BootApp extends StatefulWidget {
  const _BootApp({
    required this.backendController,
    required this.sessionController,
    required this.localeController,
    required this.brandIconController,
    required this.themeController,
    required this.initialLocation,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final LocaleController localeController;
  final BrandIconController brandIconController;
  final ThemeController themeController;
  final String? initialLocation;

  @override
  State<_BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<_BootApp> {
  bool _showSplash = true;

  void _onSplashFinished() {
    if (!mounted || !_showSplash) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return ThemeControllerScope(
      controller: widget.themeController,
      child: BrandIconScope(
        controller: widget.brandIconController,
        child: _showSplash
            ? MaterialApp(
                debugShowCheckedModeBanner: false,
                home: LaunchSplash(
                  backendController: widget.backendController,
                  onFinished: _onSplashFinished,
                ),
              )
            : TerminalViewTransition(
                child: App(
                  backendController: widget.backendController,
                  sessionController: widget.sessionController,
                  localeController: widget.localeController,
                  themeController: widget.themeController,
                  initialLocation: widget.initialLocation,
                ),
              ),
      ),
    );
  }
}
