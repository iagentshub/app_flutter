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
    with TickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 950);
  static const _initialPause = Duration(milliseconds: 140);
  static const _animationDuration = Duration(milliseconds: 1050);
  static const _finalPause = Duration(milliseconds: 260);

  /// Máximo que se espera a que llegue la config de plataforma (ciclos/modo
  /// final) antes de arrancar la animación igualmente con los valores por
  /// defecto — un backend lento o inalcanzable no debe congelar el splash.
  static const _configTimeout = Duration(milliseconds: 400);

  /// Formación inicial del icono: las líneas se trazan y el punto cae antes
  /// de que arranque el ciclo de morph gobernado por [_controller].
  late final AnimationController _entranceController;
  late final AnimationController _controller;

  /// Un ciclo = una ida y vuelta completa A→B→A del logo.
  int _cycles = 1;
  bool _endOnLogo = true;
  SplashMark _targetMark = SplashMark.ia;

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
    await _entranceController.forward();
    if (!mounted) return;

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
          child: CoordinatorToIaMark(
            animation: _controller,
            entrance: _entranceController,
            mark: _targetMark,
          ),
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
    Animation<double>? entrance,
    this.size = 124,
    super.key,
  }) : entrance = entrance ?? const AlwaysStoppedAnimation<double>(1);

  final Animation<double> animation;

  /// Animación de formación inicial del icono (líneas trazándose y punto
  /// cayendo). Mientras no esté completa, sustituye al morph coordinador↔iA.
  final Animation<double> entrance;
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
                animation: Listenable.merge([animation, entrance]),
                builder: (context, _) {
                  if (entrance.value < 1.0) {
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
                      mark: mark,
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

/// Formación de entrada del símbolo del coordinador: cada línea (brazos,
/// conector, tronco) se traza serpenteando su contorno y luego se rellena de
/// sólido, mientras el punto cae desde arriba y rebota al posarse. El último
/// frame coincide exactamente con `progress: 0` de [CoordinatorToIaPainter],
/// así que el relevo entre ambos painters no da salto visual.
class MarkEntrancePainter extends CustomPainter {
  const MarkEntrancePainter({required this.progress});

  /// 0..1 sobre la duración total de la entrada.
  final double progress;

  /// Fracción del intervalo de cada pieza dedicada a trazar su contorno; el
  /// resto se dedica a desvanecer ese trazo mientras aparece el relleno.
  static const _traceFraction = 0.65;
  static const _strokeWidthFactor = 0.032;

  /// Punto de partida del punto, por encima del lienzo (fracción de alto).
  static const _dotDropStartY = -0.35;

  static const _leftInterval = Interval(0, 0.55, curve: Curves.easeInOut);
  static const _rightInterval = Interval(0.08, 0.62, curve: Curves.easeInOut);
  static const _stemInterval = Interval(0.20, 0.68, curve: Curves.easeInOut);
  static const _connectorInterval = Interval(
    0.36,
    0.80,
    curve: Curves.easeInOut,
  );
  static const _dotInterval = Interval(0.55, 1);

  Offset _scaled(Size size, BrandPoint point) =>
      Offset(point.x * size.width, point.y * size.height);

  Path _polygonPath(Size size, List<BrandPoint> points) {
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final offset = _scaled(size, points[index]);
      if (index == 0) {
        path.moveTo(offset.dx, offset.dy);
      } else {
        path.lineTo(offset.dx, offset.dy);
      }
    }
    return path..close();
  }

  Path _rectPath(Size size, BrandRect rect, double cornerRadius) {
    final scaledRect = Rect.fromLTRB(
      rect.left * size.width,
      rect.top * size.height,
      rect.right * size.width,
      rect.bottom * size.height,
    );
    return Path()
      ..addRRect(
        RRect.fromRectAndRadius(scaledRect, Radius.circular(cornerRadius)),
      );
  }

  /// Traza el contorno de [path] hasta `pieceProgress`, después desvanece
  /// ese trazo mientras aparece el relleno sólido — la "serpiente" se
  /// convierte en la forma final.
  void _paintSnakePiece(Canvas canvas, Size size, Path path, double pieceT) {
    if (pieceT <= 0) return;
    final traceT = (pieceT / _traceFraction).clamp(0.0, 1.0);
    final fillT = ((pieceT - _traceFraction) / (1 - _traceFraction)).clamp(
      0.0,
      1.0,
    );

    if (traceT > 0 && fillT < 1) {
      final metric = path.computeMetrics().first;
      final traced = metric.extractPath(0, metric.length * traceT);
      canvas.drawPath(
        traced,
        Paint()
          ..color = FncColors.white.withValues(alpha: 1 - fillT)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.shortestSide * _strokeWidthFactor
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
    if (fillT > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = FncColors.white.withValues(alpha: fillT)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = size.shortestSide;
    final cornerRadius =
        shortestSide * BrandMarkGeometry.coordinatorCornerRadius;

    _paintSnakePiece(
      canvas,
      size,
      _polygonPath(size, BrandMarkGeometry.coordinatorLeft),
      _leftInterval.transform(progress),
    );
    _paintSnakePiece(
      canvas,
      size,
      _polygonPath(size, BrandMarkGeometry.coordinatorRight),
      _rightInterval.transform(progress),
    );
    _paintSnakePiece(
      canvas,
      size,
      _rectPath(size, BrandMarkGeometry.coordinatorConnector, cornerRadius),
      _connectorInterval.transform(progress),
    );
    _paintSnakePiece(
      canvas,
      size,
      _rectPath(size, BrandMarkGeometry.coordinatorStem, cornerRadius),
      _stemInterval.transform(progress),
    );

    final dotT = Curves.bounceOut.transform(
      _dotInterval.transform(progress),
    );
    if (dotT > 0) {
      final dotStart = Offset(
        BrandMarkGeometry.coordinatorDot.x * size.width,
        _dotDropStartY * size.height,
      );
      final dotEnd = _scaled(size, BrandMarkGeometry.coordinatorDot);
      canvas.drawCircle(
        Offset.lerp(dotStart, dotEnd, dotT)!,
        shortestSide * BrandMarkGeometry.coordinatorDotRadius,
        Paint()..color = FncColors.white,
      );
    }
  }

  @override
  bool shouldRepaint(MarkEntrancePainter oldDelegate) =>
      oldDelegate.progress != progress;
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
