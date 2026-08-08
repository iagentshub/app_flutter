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

/// Los tres estados de la secuencia fija de arranque.
enum SplashMark { logo, ia, ai }

const splashSequence = [
  SplashMark.logo,
  SplashMark.ia,
  SplashMark.ai,
  SplashMark.logo,
];

class _LaunchSplashState extends State<LaunchSplash>
    with TickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 950);
  static const _initialPause = Duration(milliseconds: 140);
  static const _animationDuration = Duration(milliseconds: 1050);
  static const _finalPause = Duration(milliseconds: 260);
  static const _configTimeout = Duration(milliseconds: 400);

  late final AnimationController _entranceController;
  late final AnimationController _controller;

  SplashMark _fromMark = SplashMark.logo;
  SplashMark _toMark = SplashMark.ia;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: _entranceDuration,
    );
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
    );
    unawaited(_runSequence());
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _controller.dispose();
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

  Future<void> _runSequence() async {
    await _entranceController.forward();
    if (!mounted) return;
    await Future<void>.delayed(_initialPause);
    if (!mounted) return;

    await Future.any([
      _warmPlatformCache(),
      Future<void>.delayed(_configTimeout),
    ]);
    if (!mounted) return;

    for (var index = 0; index < splashSequence.length - 1; index++) {
      await _playTransition(splashSequence[index], splashSequence[index + 1]);
      if (!mounted) return;
    }
    await Future<void>.delayed(_finalPause);
    if (mounted) widget.onFinished();
  }

  Future<void> _playTransition(SplashMark from, SplashMark to) async {
    setState(() {
      _fromMark = from;
      _toMark = to;
    });
    _controller.reset();
    await _controller.forward();
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
          child: CoordinatorToIaMark(
            animation: _controller,
            entrance: _entranceController,
            fromMark: _fromMark,
            toMark: _toMark,
          ),
        ),
      ),
    );
  }
}

/// Superficie de marca del splash. El nombre de clase se conserva para no
/// romper consumidores internos del painter.
class CoordinatorToIaMark extends StatelessWidget {
  const CoordinatorToIaMark({
    required this.animation,
    required this.fromMark,
    required this.toMark,
    Animation<double>? entrance,
    this.size = 124,
    super.key,
  }) : entrance = entrance ?? const AlwaysStoppedAnimation<double>(1);

  final Animation<double> animation;
  final Animation<double> entrance;
  final SplashMark fromMark;
  final SplashMark toMark;
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
            borderRadius: BorderRadius.circular(
              size * BrandMarkGeometry.tileCornerRadius,
            ),
            boxShadow: const [
              BoxShadow(
                color: FncColors.overlayMaroon40,
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              size * BrandMarkGeometry.tileCornerRadius,
            ),
            child: ColoredBox(
              color: FncColors.red,
              child: AnimatedBuilder(
                animation: Listenable.merge([animation, entrance]),
                builder: (context, _) {
                  if (entrance.value < 1) {
                    return CustomPaint(
                      key: const Key('splash-icon-entrance'),
                      painter: MarkEntrancePainter(progress: entrance.value),
                    );
                  }
                  return CustomPaint(
                    key: const Key('splash-icon-morph'),
                    painter: CoordinatorToIaPainter(
                      progress: Curves.easeInOutCubic.transform(
                        animation.value,
                      ),
                      fromMark: fromMark,
                      toMark: toMark,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Path _cubicPath(Size size, BrandCubic curve) {
  Offset point(BrandPoint value) =>
      Offset(value.x * size.width, value.y * size.height);

  final start = point(curve.start);
  final control1 = point(curve.control1);
  final control2 = point(curve.control2);
  final end = point(curve.end);
  return Path()
    ..moveTo(start.dx, start.dy)
    ..cubicTo(
      control1.dx,
      control1.dy,
      control2.dx,
      control2.dy,
      end.dx,
      end.dy,
    );
}

Path _linePath(Size size, BrandLine line) {
  return Path()
    ..moveTo(line.start.x * size.width, line.start.y * size.height)
    ..lineTo(line.end.x * size.width, line.end.y * size.height);
}

Paint _brandStroke(Size size, {double opacity = 1}) {
  return Paint()
    ..color = FncColors.white.withValues(alpha: opacity)
    ..style = PaintingStyle.stroke
    ..strokeWidth = size.shortestSide * BrandMarkGeometry.strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}

class MarkEntrancePainter extends CustomPainter {
  const MarkEntrancePainter({required this.progress});

  final double progress;

  void _drawPartial(Canvas canvas, Path path, Paint paint, double value) {
    if (value <= 0) return;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * value), paint);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = _brandStroke(size);
    final armsT = Curves.easeInOut.transform(
      const Interval(0, 0.72).transform(progress),
    );
    final stemT = Curves.easeOut.transform(
      const Interval(0.18, 0.78).transform(progress),
    );
    _drawPartial(
      canvas,
      _cubicPath(size, BrandMarkGeometry.coordinatorLeft),
      paint,
      armsT,
    );
    _drawPartial(
      canvas,
      _cubicPath(size, BrandMarkGeometry.coordinatorRight),
      paint,
      armsT,
    );
    _drawPartial(
      canvas,
      _linePath(size, BrandMarkGeometry.coordinatorStem),
      paint,
      stemT,
    );

    final dotT = Curves.bounceOut.transform(
      const Interval(0.55, 1).transform(progress),
    );
    if (dotT > 0) {
      final start = Offset(size.width * 0.5, -size.height * 0.2);
      final end = Offset(
        BrandMarkGeometry.coordinatorDot.x * size.width,
        BrandMarkGeometry.coordinatorDot.y * size.height,
      );
      canvas.drawCircle(
        Offset.lerp(start, end, dotT)!,
        size.shortestSide * BrandMarkGeometry.coordinatorDotRadius,
        Paint()..color = FncColors.white,
      );
    }
  }

  @override
  bool shouldRepaint(MarkEntrancePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class CoordinatorToIaPainter extends CustomPainter {
  const CoordinatorToIaPainter({
    required this.progress,
    required this.fromMark,
    required this.toMark,
  });

  final double progress;
  final SplashMark fromMark;
  final SplashMark toMark;

  BrandCubic _left(SplashMark mark) => switch (mark) {
    SplashMark.logo => BrandMarkGeometry.coordinatorLeft,
    SplashMark.ia => BrandMarkGeometry.iaLeft,
    SplashMark.ai => BrandMarkGeometry.aiLeft,
  };

  BrandCubic _right(SplashMark mark) => switch (mark) {
    SplashMark.logo => BrandMarkGeometry.coordinatorRight,
    SplashMark.ia => BrandMarkGeometry.iaRight,
    SplashMark.ai => BrandMarkGeometry.aiRight,
  };

  BrandLine _stem(SplashMark mark) => switch (mark) {
    SplashMark.logo => BrandMarkGeometry.coordinatorStem,
    SplashMark.ia => BrandMarkGeometry.iaStem,
    SplashMark.ai => BrandMarkGeometry.aiStem,
  };

  BrandLine _connector(SplashMark mark) => switch (mark) {
    SplashMark.logo => BrandMarkGeometry.coordinatorConnector,
    SplashMark.ia => BrandMarkGeometry.iaConnector,
    SplashMark.ai => BrandMarkGeometry.aiConnector,
  };

  BrandPoint _dot(SplashMark mark) => switch (mark) {
    SplashMark.logo => BrandMarkGeometry.coordinatorDot,
    SplashMark.ia => BrandMarkGeometry.iaDot,
    SplashMark.ai => BrandMarkGeometry.aiDot,
  };

  double _dotRadius(SplashMark mark) => mark == SplashMark.logo
      ? BrandMarkGeometry.coordinatorDotRadius
      : BrandMarkGeometry.letterDotRadius;

  BrandPoint _point(BrandPoint start, BrandPoint end) {
    return BrandPoint(
      start.x + ((end.x - start.x) * progress),
      start.y + ((end.y - start.y) * progress),
    );
  }

  BrandCubic _curve(BrandCubic start, BrandCubic end) {
    return BrandCubic(
      _point(start.start, end.start),
      _point(start.control1, end.control1),
      _point(start.control2, end.control2),
      _point(start.end, end.end),
    );
  }

  BrandLine _line(BrandLine start, BrandLine end) {
    return BrandLine(
      _point(start.start, end.start),
      _point(start.end, end.end),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = _brandStroke(size);
    canvas
      ..drawPath(
        _cubicPath(size, _curve(_left(fromMark), _left(toMark))),
        stroke,
      )
      ..drawPath(
        _cubicPath(size, _curve(_right(fromMark), _right(toMark))),
        stroke,
      )
      ..drawPath(_linePath(size, _line(_stem(fromMark), _stem(toMark))), stroke)
      ..drawPath(
        _linePath(size, _line(_connector(fromMark), _connector(toMark))),
        stroke,
      );

    final dot = _point(_dot(fromMark), _dot(toMark));
    final fromDotRadius = _dotRadius(fromMark);
    final dotRadius =
        fromDotRadius + ((_dotRadius(toMark) - fromDotRadius) * progress);
    canvas.drawCircle(
      Offset(dot.x * size.width, dot.y * size.height),
      dotRadius * size.shortestSide,
      Paint()..color = FncColors.white,
    );
  }

  @override
  bool shouldRepaint(CoordinatorToIaPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fromMark != fromMark ||
      oldDelegate.toMark != toMark;
}
