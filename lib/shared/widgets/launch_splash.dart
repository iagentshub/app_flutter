import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../core/network/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../branding/brand_mark_geometry.dart';
import '../state/backend_controller.dart';
import '../state/boot_platform_cache.dart';

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

/// Las tres formas del icono del splash. `ia` es la marca canónica
/// ("i" + "A"); `ai` es su espejo horizontal, usado como variación en el
/// ciclo de la animación de arranque.
enum SplashMark { ia, ai }

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  static const _initialPause = Duration(milliseconds: 140);
  static const _animationDuration = Duration(milliseconds: 1050);
  static const _finalPause = Duration(milliseconds: 260);

  /// Máximo que se espera a que llegue la config de plataforma (ciclos/modo
  /// final) antes de arrancar la animación igualmente con los valores por
  /// defecto — un backend lento o inalcanzable no debe congelar el splash.
  static const _configTimeout = Duration(milliseconds: 400);

  late final AnimationController _controller;

  /// Un ciclo = una ida y vuelta completa A→B→A del logo.
  int _cycles = 1;
  bool _endOnLogo = true;
  SplashMark _targetMark = SplashMark.ia;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    unawaited(_runSequence());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformConfig() async {
    final apiClient = ApiClient(widget.backendController);
    final authRepository = AuthRepository(apiClient);
    try {
      final platform = await authRepository.platformPublic();
      BootPlatformCache.set(platform: platform, reachable: true);
      if (!mounted) return;
      _cycles = _asCycles(platform['splash_cycles']);
      _endOnLogo = platform['splash_end_on_logo'] != false;
    } catch (_) {
      BootPlatformCache.set(platform: null, reachable: false);
    }
  }

  int _asCycles(Object? value) {
    if (value is num) return value.toInt().clamp(1, 10);
    return 1;
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(_initialPause);
    if (!mounted) return;

    // Se espera un poco a la config real (ciclos/modo final), pero sin
    // bloquear el splash si el backend tarda o no responde — mejor arrancar
    // con los valores por defecto que dejar la pantalla congelada.
    await Future.any([
      _loadPlatformConfig(),
      Future<void>.delayed(_configTimeout),
    ]);
    if (!mounted) return;

    // Instantánea local: si _loadPlatformConfig sigue en vuelo tras el
    // timeout y termina a mitad del bucle, no debe alterar cuántas vueltas
    // ya decidimos dar.
    final cycles = _cycles;
    final endOnLogo = _endOnLogo;
    for (var i = 0; i < cycles; i++) {
      await _playMark(SplashMark.ia);
      if (!mounted) return;
      await _playMark(SplashMark.ai);
      if (!mounted) return;
    }
    if (endOnLogo) {
      setState(() => _targetMark = SplashMark.ia);
      await _controller.forward();
      if (!mounted) return;
    }
    await Future<void>.delayed(_finalPause);
    if (mounted) widget.onFinished();
  }

  /// Una "pata" del ciclo: símbolo → [mark] → símbolo.
  Future<void> _playMark(SplashMark mark) async {
    setState(() => _targetMark = mark);
    await _controller.forward();
    if (!mounted) return;
    await _controller.reverse();
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
        child: Center(
          child: CoordinatorToIaMark(animation: _controller, mark: _targetMark),
        ),
      ),
    );
  }
}

/// Transición contenida en una única superficie: el coordinador se repliega
/// mientras la marca iA ocupa su lugar. Al compartir encuadre y color de fondo
/// se percibe como una transformación, no como dos logos consecutivos.
class CoordinatorToIaMark extends StatelessWidget {
  const CoordinatorToIaMark({
    required this.animation,
    required this.mark,
    this.size = 124,
    super.key,
  });

  final Animation<double> animation;
  final SplashMark mark;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'iAgents',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: const [
              BoxShadow(
                color: FncColors.overlayMaroon40,
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: ColoredBox(
              color: FncColors.red,
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) => CustomPaint(
                  key: const Key('splash-icon-morph'),
                  painter: CoordinatorToIaPainter(
                    progress: Curves.easeInOutCubic.transform(animation.value),
                    mark: mark,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Morph vectorial con correspondencia entre trazos:
/// punto → punto de la i, tronco → cuerpo de la i y brazos → patas de la A.
class CoordinatorToIaPainter extends CustomPainter {
  const CoordinatorToIaPainter({required this.progress, required this.mark});

  final double progress;
  final SplashMark mark;

  List<BrandPoint> get _targetLeft => mark == SplashMark.ia
      ? BrandMarkGeometry.iaLeft
      : BrandMarkGeometry.aiLeft;
  List<BrandPoint> get _targetRight => mark == SplashMark.ia
      ? BrandMarkGeometry.iaRight
      : BrandMarkGeometry.aiRight;
  BrandRect get _targetConnector => mark == SplashMark.ia
      ? BrandMarkGeometry.iaConnector
      : BrandMarkGeometry.aiConnector;
  BrandRect get _targetStem => mark == SplashMark.ia
      ? BrandMarkGeometry.iaStem
      : BrandMarkGeometry.aiStem;
  BrandPoint get _targetDot => mark == SplashMark.ia
      ? BrandMarkGeometry.iaDot
      : BrandMarkGeometry.aiDot;
  double get _targetDotRadius => mark == SplashMark.ia
      ? BrandMarkGeometry.iaDotRadius
      : BrandMarkGeometry.aiDotRadius;

  Offset _point(Size size, BrandPoint start, BrandPoint end) {
    return Offset.lerp(
      Offset(start.x * size.width, start.y * size.height),
      Offset(end.x * size.width, end.y * size.height),
      progress,
    )!;
  }

  Rect _rect(Size size, BrandRect start, BrandRect end) {
    final normalized = Rect.lerp(
      Rect.fromLTRB(start.left, start.top, start.right, start.bottom),
      Rect.fromLTRB(end.left, end.top, end.right, end.bottom),
      progress,
    )!;
    return Rect.fromLTRB(
      normalized.left * size.width,
      normalized.top * size.height,
      normalized.right * size.width,
      normalized.bottom * size.height,
    );
  }

  void _drawPolygon(
    Canvas canvas,
    Size size,
    Paint paint,
    List<BrandPoint> start,
    List<BrandPoint> end,
  ) {
    assert(start.length == end.length);
    final path = Path();
    for (var index = 0; index < start.length; index++) {
      final point = _point(size, start[index], end[index]);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = size.shortestSide;
    final fillPaint = Paint()
      ..color = FncColors.white
      ..style = PaintingStyle.fill;

    _drawPolygon(
      canvas,
      size,
      fillPaint,
      BrandMarkGeometry.coordinatorLeft,
      _targetLeft,
    );

    _drawPolygon(
      canvas,
      size,
      fillPaint,
      BrandMarkGeometry.coordinatorRight,
      _targetRight,
    );

    final connectorRect = _rect(
      size,
      BrandMarkGeometry.coordinatorConnector,
      _targetConnector,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        connectorRect,
        Radius.circular(
          shortestSide *
              BrandMarkGeometry.coordinatorCornerRadius *
              (1 - progress),
        ),
      ),
      fillPaint,
    );

    final stemRect = _rect(
      size,
      BrandMarkGeometry.coordinatorStem,
      _targetStem,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        stemRect,
        Radius.circular(
          shortestSide *
              BrandMarkGeometry.coordinatorCornerRadius *
              (1 - progress),
        ),
      ),
      fillPaint,
    );

    final dotCenter = _point(
      size,
      BrandMarkGeometry.coordinatorDot,
      _targetDot,
    );
    canvas.drawCircle(
      dotCenter,
      shortestSide *
          (BrandMarkGeometry.coordinatorDotRadius -
              ((BrandMarkGeometry.coordinatorDotRadius - _targetDotRadius) *
                  progress)),
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(CoordinatorToIaPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.mark != mark;
  }
}
