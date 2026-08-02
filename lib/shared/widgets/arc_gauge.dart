import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Anillo de progreso circular tipo KPI — sin dependencias externas.
///
/// El track (la parte no rellenada) usa el mismo tono que el arco relleno a
/// baja opacidad ("mismo hue, un paso más claro") en vez de un gris neutro,
/// para que el estado se lea de un vistazo incluso sin mirar el número.
class ArcGauge extends StatelessWidget {
  const ArcGauge({
    required this.progress,
    required this.color,
    this.size = 56,
    this.strokeWidth = 6,
    this.child,
    super.key,
  });

  /// 0.0–1.0. Valores fuera de rango se recortan al pintar.
  final double progress;
  final Color color;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ArcGaugePainter(
          progress: progress.clamp(0.0, 1.0),
          color: color,
          trackColor: color.withValues(alpha: 0.15),
          strokeWidth: strokeWidth,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  static const _startAngle = -math.pi / 2;
  static const _fullSweep = 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, _fullSweep, false, trackPaint);

    if (progress <= 0) return;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _fullSweep * progress, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
