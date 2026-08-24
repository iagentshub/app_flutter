import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../state/backend_controller.dart';
import '../state/boot_platform_cache.dart';
import 'dakreo_signature.dart';
import 'static_iagents_mark.dart';

class LaunchSplash extends StatefulWidget {
  const LaunchSplash({
    required this.backendController,
    required this.onFinished,
    super.key,
  });

  final BackendController backendController;
  final VoidCallback onFinished;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

/// Tiempo mínimo del splash cuando el sistema solicita reducir o desactivar
/// las animaciones.
const reducedMotionSplashDuration = Duration(milliseconds: 850);

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  static const _dakreoDuration = Duration(milliseconds: 1100);
  static const _finalPause = Duration(milliseconds: 220);
  static const _configTimeout = Duration(milliseconds: 400);

  late final AnimationController _dakreoController;
  bool _sequenceStarted = false;

  @override
  void initState() {
    super.initState();
    _dakreoController = AnimationController(
      vsync: this,
      duration: _dakreoDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_sequenceStarted) return;
    _sequenceStarted = true;

    if (MediaQuery.disableAnimationsOf(context)) {
      _dakreoController.value = 1;
      unawaited(_runStaticSequence());
    } else {
      unawaited(_runAnimatedSequence());
    }
  }

  @override
  void dispose() {
    _dakreoController.dispose();
    super.dispose();
  }

  Future<void> _warmPlatformCache() async {
    final apiClient = ApiClient(widget.backendController);
    final authRepository = AuthRepository(apiClient);
    try {
      final platform = await authRepository.platformPublic();
      BootPlatformCache.set(platform: platform, reachable: true);
    } catch (_) {
      BootPlatformCache.set(platform: null, reachable: false);
    }
  }

  Future<void> _runStaticSequence() async {
    unawaited(_warmPlatformCache());
    await Future<void>.delayed(reducedMotionSplashDuration);
    if (mounted) widget.onFinished();
  }

  Future<void> _runAnimatedSequence() async {
    final platformWarmup = _warmPlatformCache();
    await _dakreoController.forward();
    if (!mounted) return;
    await Future.any([platformWarmup, Future<void>.delayed(_configTimeout)]);
    if (!mounted) return;
    await Future<void>.delayed(_finalPause);
    if (mounted) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FncColors.gray050505,
              FncColors.gray101010,
              FncColors.gray161616,
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Center(child: StaticIAgentsMark()),
            SafeArea(
              child: Align(
                key: const Key('dakreo-signature-position'),
                alignment: const Alignment(0, 0.58),
                child: DakreoSignature(animation: _dakreoController),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
