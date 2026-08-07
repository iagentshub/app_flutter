import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import 'graph_models.dart';

/// Pinta las aristas del grafo animado: líneas rectas (con progreso de
/// entrada) o discontinuas para las conexiones marcadas como `dashed` (p.
/// ej. un bucle en una orquestación).
class GraphEdgePainter extends CustomPainter {
  GraphEdgePainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.progress,
    this.lineColor = FncColors.materialGrey,
    this.dashedColor = FncColors.materialOrange,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<Offset> positions;
  final double progress;

  /// Color de las aristas normales/discontinuas. Ya incluye la opacidad
  /// deseada: el pintor no aplica ninguna adicional, para que el modo
  /// galaxia pueda usar líneas más tenues sobre su fondo oscuro.
  final Color lineColor;
  final Color dashedColor;

  Offset? _posFor(String id) {
    final index = nodes.indexWhere((n) => n.id == id);
    if (index == -1) return null;
    return positions[index];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final edge in edges) {
      final start = _posFor(edge.sourceId);
      final end = _posFor(edge.targetId);
      if (start == null || end == null) continue;
      final current = Offset.lerp(start, end, progress.clamp(0.0, 1.0))!;
      final paint = Paint()
        ..color = edge.dashed ? dashedColor : lineColor
        ..strokeWidth = edge.dashed ? 1.6 : 2.2
        ..style = PaintingStyle.stroke;
      if (edge.dashed) {
        _drawDashedLine(canvas, start, current, paint);
      } else {
        canvas.drawLine(start, current, paint);
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final total = (end - start).distance;
    if (total == 0) return;
    final direction = (end - start) / total;
    var covered = 0.0;
    while (covered < total) {
      final segEnd = math.min(covered + dashWidth, total);
      canvas.drawLine(
        start + direction * covered,
        start + direction * segEnd,
        paint,
      );
      covered += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant GraphEdgePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dashedColor != dashedColor;
}
