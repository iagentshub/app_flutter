import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app/app.dart';
import 'app/router/url_strategy.dart';
import 'core/config/runtime_config.dart';
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
    ),
  );
}

class _BootApp extends StatefulWidget {
  const _BootApp({
    required this.backendController,
    required this.sessionController,
    required this.localeController,
    required this.brandIconController,
    required this.themeController,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final LocaleController localeController;
  final BrandIconController brandIconController;
  final ThemeController themeController;

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
                ),
              ),
      ),
    );
  }
}
