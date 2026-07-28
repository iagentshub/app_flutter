import 'package:flutter/material.dart';

import 'app/app.dart';
import 'shared/state/backend_controller.dart';
import 'shared/state/session_controller.dart';
import 'shared/widgets/terminal_boot_sequence.dart';
import 'shared/widgets/launch_splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backendController = await BackendController.bootstrap();
  final sessionController = await SessionController.bootstrap();

  runApp(
    _BootApp(
      backendController: backendController,
      sessionController: sessionController,
    ),
  );
}

class _BootApp extends StatefulWidget {
  const _BootApp({
    required this.backendController,
    required this.sessionController,
  });

  final BackendController backendController;
  final SessionController sessionController;

  @override
  State<_BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<_BootApp> {
  _BootStage _stage = _BootStage.splash;

  void _onSplashFinished() {
    if (!mounted || _stage != _BootStage.splash) return;
    setState(() => _stage = _BootStage.terminal);
  }

  void _onTerminalFinished() {
    if (!mounted || _stage != _BootStage.terminal) return;
    setState(() => _stage = _BootStage.app);
  }

  @override
  Widget build(BuildContext context) {
    if (_stage != _BootStage.app) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: _stage == _BootStage.splash
              ? LaunchSplash(
                  key: const ValueKey('launch-splash'),
                  onFinished: _onSplashFinished,
                )
              : TerminalBootSequence(
                  key: const ValueKey('terminal-boot'),
                  onFinished: _onTerminalFinished,
                ),
        ),
      );
    }

    return App(
      backendController: widget.backendController,
      sessionController: widget.sessionController,
    );
  }
}

enum _BootStage { splash, terminal, app }
