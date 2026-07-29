import 'package:flutter/material.dart';

import 'app/app.dart';
import 'shared/state/backend_controller.dart';
import 'shared/state/locale_controller.dart';
import 'shared/state/session_controller.dart';
import 'shared/widgets/launch_splash.dart';
import 'shared/widgets/terminal_view_transition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Los 3 bootstrap son independientes entre sí (cada uno lee su propia
  // clave de SharedPreferences) — en paralelo en vez de en cadena ahorra
  // 2 de las 3 esperas de plugin channel en el arranque.
  final results = await Future.wait([
    BackendController.bootstrap(),
    SessionController.bootstrap(),
    LocaleController.bootstrap(),
  ]);
  final backendController = results[0] as BackendController;
  final sessionController = results[1] as SessionController;
  final localeController = results[2] as LocaleController;

  runApp(
    _BootApp(
      backendController: backendController,
      sessionController: sessionController,
      localeController: localeController,
    ),
  );
}

class _BootApp extends StatefulWidget {
  const _BootApp({
    required this.backendController,
    required this.sessionController,
    required this.localeController,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final LocaleController localeController;

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
    if (_showSplash) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LaunchSplash(
          backendController: widget.backendController,
          onFinished: _onSplashFinished,
        ),
      );
    }

    return TerminalViewTransition(
      child: App(
        backendController: widget.backendController,
        sessionController: widget.sessionController,
        localeController: widget.localeController,
      ),
    );
  }
}
