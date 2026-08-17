import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../labels/label_catalog.dart';
import 'galaxy_layout.dart';
import 'graph_models.dart';

/// Delimita visualmente cada familia sin convertir la galaxia en un diagrama
/// de cajas. Los halos ayudan a leer los grupos cuando las etiquetas están
/// ocultas y permanecen lo bastante tenues para no competir con las aristas.
class GalaxyConstellationPainter extends CustomPainter {
  const GalaxyConstellationPainter({
    required this.nodes,
    required this.rootId,
    required this.centers,
  });

  final List<GraphNode> nodes;
  final String rootId;
  final Map<String, Offset> centers;

  @override
  void paint(Canvas canvas, Size size) {
    final counts = <String, int>{};
    final types = <String, String>{};
    for (final node in nodes) {
      if (node.id == rootId) continue;
      final key = GalaxyLayout.constellationKey(node.type);
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
      types.putIfAbsent(key, () => node.type);
    }

    for (final entry in centers.entries) {
      final count = counts[entry.key] ?? 1;
      final color = labelColor(types[entry.key] ?? '');
      final radius = (48 + math.sqrt(count) * 19).clamp(68.0, 126.0);
      final rect = Rect.fromCircle(center: entry.value, radius: radius);
      canvas.drawCircle(
        entry.value,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.075),
              color.withValues(alpha: 0.018),
              FncColors.transparent,
            ],
            stops: const [0, 0.58, 1],
          ).createShader(rect),
      );
      canvas.drawCircle(
        entry.value,
        radius * 0.78,
        Paint()
          ..color = color.withValues(alpha: 0.11)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

      final accentPaint = Paint()
        ..color = color.withValues(alpha: 0.36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect.deflate(radius * 0.22),
        -0.7,
        0.72,
        false,
        accentPaint,
      );
      canvas.drawArc(
        rect.deflate(radius * 0.22),
        math.pi - 0.7,
        0.42,
        false,
        accentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant GalaxyConstellationPainter oldDelegate) =>
      oldDelegate.nodes != nodes ||
      oldDelegate.rootId != rootId ||
      oldDelegate.centers != centers;
}
