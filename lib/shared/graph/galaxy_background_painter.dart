import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

/// Fondo procedural y estático del observatorio. La semilla fija evita que
/// las estrellas "salten" entre reconstrucciones y no mantiene ningún ticker
/// activo cuando el usuario deja el grafo en reposo.
class GalaxyBackgroundPainter extends CustomPainter {
  const GalaxyBackgroundPainter();

  static const _seed = 20260815;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            FncColors.gray111111,
            FncColors.gray0E0E0E,
            FncColors.gray070707,
          ],
          stops: [0, 0.46, 1],
        ).createShader(rect),
    );

    final focusRect = Rect.fromCenter(
      center: Offset(size.width * 0.5, size.height * 0.48),
      width: size.width * 1.1,
      height: size.height * 0.82,
    );
    canvas.drawOval(
      focusRect,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x0DFFFFFF), Color(0x04FFFFFF), FncColors.transparent],
          stops: [0, 0.48, 1],
        ).createShader(focusRect),
    );

    final random = math.Random(_seed);
    final dustCount = (size.width * size.height / 30000).round().clamp(18, 54);
    for (var i = 0; i < dustCount; i++) {
      final position = Offset(
        random.nextDouble() * size.width,
        random.nextDouble() * size.height,
      );
      final radius = 0.28 + random.nextDouble() * 0.42;
      final alpha = 0.07 + random.nextDouble() * 0.11;
      canvas.drawCircle(
        position,
        radius,
        Paint()..color = FncColors.galaxyStar.withValues(alpha: alpha),
      );
    }

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          radius: 0.96,
          colors: [FncColors.transparent, Color(0xB8000000)],
          stops: [0.52, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant GalaxyBackgroundPainter oldDelegate) => false;
}
