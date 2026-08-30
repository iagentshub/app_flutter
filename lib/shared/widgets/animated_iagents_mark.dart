import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../branding/brand_mark_geometry.dart';

/// Versión animada del icono de iAgents Hub. Repite `logo → iA → Ai → logo`
/// mientras permanezca montada y queda estática con movimiento reducido.
class AnimatedIAgentsMark extends StatefulWidget {
  const AnimatedIAgentsMark({this.size = 124, super.key});

  final double size;

  @override
  State<AnimatedIAgentsMark> createState() => _AnimatedIAgentsMarkState();
}

/// Reloj único para todos los indicadores de carga montados en la aplicación.
/// Solo anima mientras exista al menos un consumidor visible.
class IAgentsLoadingAnimationScope extends StatefulWidget {
  const IAgentsLoadingAnimationScope({required this.child, super.key});

  final Widget child;

  @override
  State<IAgentsLoadingAnimationScope> createState() =>
      _IAgentsLoadingAnimationScopeState();
}

class _IAgentsLoadingAnimationScopeState
    extends State<IAgentsLoadingAnimationScope>
    with SingleTickerProviderStateMixin {
  late final _LoadingAnimationClock _clock = _LoadingAnimationClock(this);

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _LoadingAnimationClockProvider(clock: _clock, child: widget.child);
}

class _LoadingAnimationClockProvider extends InheritedWidget {
  const _LoadingAnimationClockProvider({
    required this.clock,
    required super.child,
  });

  final _LoadingAnimationClock clock;

  @override
  bool updateShouldNotify(_LoadingAnimationClockProvider oldWidget) =>
      oldWidget.clock != clock;
}

_LoadingAnimationClock? _maybeLoadingClockOf(BuildContext context) => context
    .dependOnInheritedWidgetOfExactType<_LoadingAnimationClockProvider>()
    ?.clock;

class _LoadingAnimationClock {
  _LoadingAnimationClock(TickerProvider vsync)
    : animation = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 3150),
      );

  final AnimationController animation;
  int _consumers = 0;

  void acquire() {
    _consumers += 1;
    if (_consumers == 1) animation.repeat();
  }

  void release() {
    assert(_consumers > 0);
    _consumers -= 1;
    if (_consumers == 0) animation.stop();
  }

  void dispose() => animation.dispose();
}

/// Sustituto adaptable de los indicadores circulares de carga.
///
/// Conserva el mismo logo animado en toda la aplicación y toma el tamaño del
/// espacio disponible: funciona tanto en una pantalla o diálogo como dentro
/// de botones, chips y filas compactas. Si el padre no fija dimensiones usa
/// [size], limitado a [maxSize].
class IAgentsLoadingMark extends StatefulWidget {
  const IAgentsLoadingMark({
    this.size = 40,
    this.maxSize = 84,
    this.semanticsLabel,
    super.key,
  });

  final double size;
  final double maxSize;
  final String? semanticsLabel;

  @override
  State<IAgentsLoadingMark> createState() => _IAgentsLoadingMarkState();
}

class _IAgentsLoadingMarkState extends State<IAgentsLoadingMark>
    with SingleTickerProviderStateMixin {
  _LoadingAnimationClock? _clock;
  AnimationController? _fallbackAnimation;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final nextClock = reduceMotion ? null : _maybeLoadingClockOf(context);
    if (_clock != nextClock) {
      _clock?.release();
      _clock = nextClock;
      _clock?.acquire();
    }
    _reduceMotion = reduceMotion;
    if (_reduceMotion || _clock != null) {
      _fallbackAnimation?.stop();
    } else {
      (_fallbackAnimation ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3150),
      )).repeat();
    }
  }

  @override
  void dispose() {
    _clock?.release();
    _fallbackAnimation?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : widget.size;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : widget.size;
        final resolvedSize = math
            .min(math.min(availableWidth, availableHeight), widget.maxSize)
            .clamp(0.0, widget.maxSize)
            .toDouble();

        return Semantics(
          container: true,
          liveRegion: true,
          label: widget.semanticsLabel,
          child: ExcludeSemantics(
            child: Center(
              child: RepaintBoundary(
                child: _LoadingMarkCanvas(
                  size: resolvedSize,
                  animation: _clock?.animation ?? _fallbackAnimation,
                  reduceMotion: _reduceMotion,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _MarkState { logo, ia, ai }

const _sequence = [
  _MarkState.logo,
  _MarkState.ia,
  _MarkState.ai,
  _MarkState.logo,
];

/// La marca quieta, sin animación ni ciclo de morfeo.
///
/// El login la necesitaba y solo había dos formas de pintarla: `BrandIcon`,
/// que carga el PNG que el usuario haya elegido en su perfil —no la marca
/// canónica, y en el login todavía no hay usuario—, o los painters privados
/// de este archivo. Vive aquí porque aquí está la geometría; duplicarla en
/// la pantalla de acceso la habría dejado a merced del siguiente retoque
/// del logo.
class IAgentsMarkTile extends StatelessWidget {
  const IAgentsMarkTile({this.size = 44, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'iAgents Hub',
      image: true,
      child: _MarkTile(
        size: size,
        child: const CustomPaint(painter: _EntrancePainter(progress: 1)),
      ),
    );
  }
}

class _LoadingMarkCanvas extends StatelessWidget {
  const _LoadingMarkCanvas({
    required this.size,
    required this.animation,
    required this.reduceMotion,
  });

  final double size;
  final Animation<double>? animation;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    Widget paint(double value) {
      final scaled = value * 3;
      final index = scaled.floor().clamp(0, 2);
      final progress = Curves.easeInOutCubic.transform(scaled - index);
      return CustomPaint(
        key: const Key('iagents-loading-mark-morph'),
        painter: _MorphPainter(
          progress: progress,
          fromMark: _sequence[index],
          toMark: _sequence[index + 1],
        ),
      );
    }

    final content = reduceMotion || animation == null
        ? paint(0)
        : AnimatedBuilder(
            animation: animation!,
            builder: (context, _) => paint(animation!.value),
          );
    return _MarkTile(size: size, child: content);
  }
}

class _MarkTile extends StatelessWidget {
  const _MarkTile({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            size * BrandMarkGeometry.tileCornerRadius,
          ),
          boxShadow: [
            BoxShadow(
              color: FncColors.overlayMaroon40,
              blurRadius: math.min(24, size * 0.2),
              spreadRadius: math.min(1, size * 0.02),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            size * BrandMarkGeometry.tileCornerRadius,
          ),
          child: ColoredBox(color: FncColors.red, child: child),
        ),
      ),
    );
  }
}

class _AnimatedIAgentsMarkState extends State<AnimatedIAgentsMark>
    with TickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 950);
  static const _transitionDuration = Duration(milliseconds: 1050);

  late final AnimationController _entranceController;
  late final AnimationController _transitionController;
  bool? _reduceMotion;
  int _sequenceGeneration = 0;
  _MarkState _fromMark = _MarkState.logo;
  _MarkState _toMark = _MarkState.ia;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: _entranceDuration,
    );
    _transitionController = AnimationController(
      vsync: this,
      duration: _transitionDuration,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    final generation = ++_sequenceGeneration;
    _entranceController.stop();
    _transitionController.stop();

    if (reduceMotion) {
      _entranceController.value = 1;
      _transitionController.value = 0;
      _fromMark = _MarkState.logo;
      _toMark = _MarkState.logo;
      return;
    }
    unawaited(_runSequence(generation));
  }

  Future<void> _runSequence(int generation) async {
    try {
      await _entranceController.forward(from: 0).orCancel;
      while (mounted && generation == _sequenceGeneration) {
        for (var index = 0; index < _sequence.length - 1; index++) {
          if (!mounted || generation != _sequenceGeneration) return;
          setState(() {
            _fromMark = _sequence[index];
            _toMark = _sequence[index + 1];
          });
          await _transitionController.forward(from: 0).orCancel;
        }
      }
    } on TickerCanceled {
      // Cambiar a movimiento reducido o desmontar el widget cancela el ciclo.
    }
  }

  @override
  void dispose() {
    _sequenceGeneration++;
    _entranceController.dispose();
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Semantics(
      image: true,
      label: 'iAgents',
      child: _MarkTile(
        size: size,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _entranceController,
            _transitionController,
          ]),
          builder: (context, _) {
            if (_entranceController.value < 1) {
              return CustomPaint(
                key: const Key('iagents-mark-animated-entrance'),
                painter: _EntrancePainter(progress: _entranceController.value),
              );
            }
            return KeyedSubtree(
              key: ValueKey(
                'iagents-transition-${_fromMark.name}-${_toMark.name}',
              ),
              child: CustomPaint(
                key: const Key('iagents-mark-animated-morph'),
                painter: _MorphPainter(
                  progress: Curves.easeInOutCubic.transform(
                    _transitionController.value,
                  ),
                  fromMark: _fromMark,
                  toMark: _toMark,
                ),
              ),
            );
          },
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

Paint _brandStroke(Size size) {
  return Paint()
    ..color = FncColors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = size.shortestSide * BrandMarkGeometry.strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
}

class _EntrancePainter extends CustomPainter {
  const _EntrancePainter({required this.progress});

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
    final arms = Curves.easeInOut.transform(
      const Interval(0, 0.72).transform(progress),
    );
    final stem = Curves.easeOut.transform(
      const Interval(0.18, 0.78).transform(progress),
    );
    _drawPartial(
      canvas,
      _cubicPath(size, BrandMarkGeometry.coordinatorLeft),
      paint,
      arms,
    );
    _drawPartial(
      canvas,
      _cubicPath(size, BrandMarkGeometry.coordinatorRight),
      paint,
      arms,
    );
    _drawPartial(
      canvas,
      _linePath(size, BrandMarkGeometry.coordinatorStem),
      paint,
      stem,
    );

    final dot = Curves.bounceOut.transform(
      const Interval(0.55, 1).transform(progress),
    );
    if (dot <= 0) return;
    final start = Offset(size.width * 0.5, -size.height * 0.2);
    final end = Offset(
      BrandMarkGeometry.coordinatorDot.x * size.width,
      BrandMarkGeometry.coordinatorDot.y * size.height,
    );
    canvas.drawCircle(
      Offset.lerp(start, end, dot)!,
      size.shortestSide * BrandMarkGeometry.coordinatorDotRadius,
      Paint()..color = FncColors.white,
    );
  }

  @override
  bool shouldRepaint(_EntrancePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _MorphPainter extends CustomPainter {
  const _MorphPainter({
    required this.progress,
    required this.fromMark,
    required this.toMark,
  });

  final double progress;
  final _MarkState fromMark;
  final _MarkState toMark;

  BrandCubic _left(_MarkState mark) => switch (mark) {
    _MarkState.logo => BrandMarkGeometry.coordinatorLeft,
    _MarkState.ia => BrandMarkGeometry.iaLeft,
    _MarkState.ai => BrandMarkGeometry.aiLeft,
  };

  BrandCubic _right(_MarkState mark) => switch (mark) {
    _MarkState.logo => BrandMarkGeometry.coordinatorRight,
    _MarkState.ia => BrandMarkGeometry.iaRight,
    _MarkState.ai => BrandMarkGeometry.aiRight,
  };

  BrandLine _stem(_MarkState mark) => switch (mark) {
    _MarkState.logo => BrandMarkGeometry.coordinatorStem,
    _MarkState.ia => BrandMarkGeometry.iaStem,
    _MarkState.ai => BrandMarkGeometry.aiStem,
  };

  BrandLine _connector(_MarkState mark) => switch (mark) {
    _MarkState.logo => BrandMarkGeometry.coordinatorConnector,
    _MarkState.ia => BrandMarkGeometry.iaConnector,
    _MarkState.ai => BrandMarkGeometry.aiConnector,
  };

  BrandPoint _dot(_MarkState mark) => switch (mark) {
    _MarkState.logo => BrandMarkGeometry.coordinatorDot,
    _MarkState.ia => BrandMarkGeometry.iaDot,
    _MarkState.ai => BrandMarkGeometry.aiDot,
  };

  double _dotRadius(_MarkState mark) => mark == _MarkState.logo
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
    final startRadius = _dotRadius(fromMark);
    final radius =
        startRadius + ((_dotRadius(toMark) - startRadius) * progress);
    canvas.drawCircle(
      Offset(dot.x * size.width, dot.y * size.height),
      radius * size.shortestSide,
      Paint()..color = FncColors.white,
    );
  }

  @override
  bool shouldRepaint(_MorphPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.fromMark != fromMark ||
      oldDelegate.toMark != toMark;
}
