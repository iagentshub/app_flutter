import 'package:flutter/material.dart';

import 'app/app.dart';
import 'shared/state/backend_controller.dart';
import 'shared/state/locale_controller.dart';
import 'shared/state/session_controller.dart';
import 'shared/widgets/launch_splash.dart';
import 'shared/widgets/terminal_view_transition.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backendController = await BackendController.bootstrap();
  final sessionController = await SessionController.bootstrap();
  final localeController = await LocaleController.bootstrap();

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
