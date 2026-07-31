import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'app/app.dart';
import 'app/router/url_strategy.dart';
import 'core/config/runtime_config.dart';
import 'shared/state/backend_controller.dart';
import 'shared/state/brand_icon_controller.dart';
import 'shared/state/locale_controller.dart';
import 'shared/state/session_controller.dart';
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
  // Los 4 bootstrap son independientes entre sí (cada uno lee su propia
  // clave de SharedPreferences) — en paralelo en vez de en cadena ahorra
  // esperas de plugin channel en el arranque.
  final results = await Future.wait([
    BackendController.bootstrap(),
    SessionController.bootstrap(),
    LocaleController.bootstrap(),
    BrandIconController.bootstrap(),
  ]);
  final backendController = results[0] as BackendController;
  final sessionController = results[1] as SessionController;
  final localeController = results[2] as LocaleController;
  final brandIconController = results[3] as BrandIconController;

  runApp(
    _BootApp(
      backendController: backendController,
      sessionController: sessionController,
      localeController: localeController,
      brandIconController: brandIconController,
    ),
  );
}

class _BootApp extends StatefulWidget {
  const _BootApp({
    required this.backendController,
    required this.sessionController,
    required this.localeController,
    required this.brandIconController,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final LocaleController localeController;
  final BrandIconController brandIconController;

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
    return BrandIconScope(
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
              ),
            ),
    );
  }
}
