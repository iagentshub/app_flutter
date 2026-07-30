import 'dart:async';

import 'package:flutter/material.dart';

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

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  static const _initialPause = Duration(milliseconds: 140);
  static const _animationDuration = Duration(milliseconds: 1050);
  static const _finalPause = Duration(milliseconds: 260);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    unawaited(_checkBackend());
    unawaited(_runSequence());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    final apiClient = ApiClient(widget.backendController);
    final authRepository = AuthRepository(apiClient);
    try {
      final platform = await authRepository.platformPublic();
      BootPlatformCache.set(platform: platform, reachable: true);
    } catch (_) {
      BootPlatformCache.set(platform: null, reachable: false);
    }
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(_initialPause);
    if (!mounted) return;
    await _controller.forward();
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
            colors: [Color(0xFF050505), Color(0xFF101010), Color(0xFF161616)],
          ),
        ),
        child: Center(child: CoordinatorToIaMark(animation: _controller)),
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
    this.size = 124,
    super.key,
  });

  final Animation<double> animation;
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
                color: Color(0x667A0C1C),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.22),
            child: ColoredBox(
              color: const Color(0xFFD90429),
              child: AnimatedBuilder(
                animation: animation,
                builder: (context, _) => CustomPaint(
                  key: const Key('splash-icon-morph'),
                  painter: CoordinatorToIaPainter(
                    progress: Curves.easeInOutCubic.transform(animation.value),
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
  const CoordinatorToIaPainter({required this.progress});

  final double progress;

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
    final mark = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    _drawPolygon(
      canvas,
      size,
      mark,
      BrandMarkGeometry.coordinatorLeft,
      BrandMarkGeometry.iaLeft,
    );

    _drawPolygon(
      canvas,
      size,
      mark,
      BrandMarkGeometry.coordinatorRight,
      BrandMarkGeometry.iaRight,
    );

    final connectorRect = _rect(
      size,
      BrandMarkGeometry.coordinatorConnector,
      BrandMarkGeometry.iaConnector,
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
      mark,
    );

    final stemRect = _rect(
      size,
      BrandMarkGeometry.coordinatorStem,
      BrandMarkGeometry.iaStem,
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
      mark,
    );

    final dotCenter = _point(
      size,
      BrandMarkGeometry.coordinatorDot,
      BrandMarkGeometry.iaDot,
    );
    canvas.drawCircle(
      dotCenter,
      shortestSide *
          (BrandMarkGeometry.coordinatorDotRadius -
              ((BrandMarkGeometry.coordinatorDotRadius -
                      BrandMarkGeometry.iaDotRadius) *
                  progress)),
      mark,
    );
  }

  @override
  bool shouldRepaint(CoordinatorToIaPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
