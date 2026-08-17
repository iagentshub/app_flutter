import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import 'galaxy_layout.dart';
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
    this.activeLineColor = FncColors.galaxyEdgeActive,
    this.galaxy = false,
    this.rootId,
    this.highlightedNodeId,
    this.constellationCenters = const {},
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
  final Color activeLineColor;
  final bool galaxy;
  final String? rootId;
  final String? highlightedNodeId;
  final Map<String, Offset> constellationCenters;

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
      final path = galaxy
          ? _galaxyPath(edge, start, end)
          : _linePath(start, end);
      final visiblePath = _visiblePath(path, progress.clamp(0.0, 1.0));
      final highlighted =
          highlightedNodeId != null &&
          (edge.sourceId == highlightedNodeId ||
              edge.targetId == highlightedNodeId);
      final paint = Paint()
        ..color = highlighted
            ? activeLineColor
            : edge.dashed
            ? dashedColor
            : lineColor
        ..strokeWidth = highlighted
            ? 2.0
            : edge.dashed
            ? 1.4
            : galaxy
            ? 1.0
            : 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (edge.dashed) {
        _drawDashedPath(canvas, visiblePath, paint);
      } else {
        canvas.drawPath(visiblePath, paint);
      }
    }
  }

  Path _linePath(Offset start, Offset end) => Path()
    ..moveTo(start.dx, start.dy)
    ..lineTo(end.dx, end.dy);

  Path _galaxyPath(GraphEdge edge, Offset start, Offset end) {
    final path = Path()..moveTo(start.dx, start.dy);
    final root = rootId;
    if (root != null && (edge.sourceId == root || edge.targetId == root)) {
      final otherId = edge.sourceId == root ? edge.targetId : edge.sourceId;
      final otherIndex = nodes.indexWhere((node) => node.id == otherId);
      final other = otherIndex == -1 ? null : nodes[otherIndex];
      final anchor = other == null
          ? null
          : constellationCenters[GalaxyLayout.constellationKey(other.type)];
      final rootPosition = edge.sourceId == root ? start : end;
      final outerPosition = edge.sourceId == root ? end : start;
      final hub = anchor == null
          ? Offset.lerp(rootPosition, outerPosition, 0.5)!
          : Offset.lerp(rootPosition, anchor, 0.52)!;
      if (edge.sourceId == root) {
        path.cubicTo(hub.dx, hub.dy, hub.dx, hub.dy, end.dx, end.dy);
      } else {
        path.cubicTo(hub.dx, hub.dy, hub.dx, hub.dy, end.dx, end.dy);
      }
      return path;
    }

    final delta = end - start;
    final midpoint = Offset.lerp(start, end, 0.5)!;
    final length = math.max(delta.distance, 1);
    final normal = Offset(-delta.dy / length, delta.dx / length);
    final direction = (edge.sourceId.hashCode ^ edge.targetId.hashCode).isEven
        ? 1.0
        : -1.0;
    final control = midpoint + normal * math.min(34, length * 0.12) * direction;
    path.quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    return path;
  }

  Path _visiblePath(Path path, double fraction) {
    final result = Path();
    for (final metric in path.computeMetrics()) {
      result.addPath(
        metric.extractPath(0, metric.length * fraction),
        Offset.zero,
      );
    }
    return result;
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var covered = 0.0;
      while (covered < metric.length) {
        final segmentEnd = math.min(covered + dashWidth, metric.length);
        canvas.drawPath(metric.extractPath(covered, segmentEnd), paint);
        covered += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GraphEdgePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges ||
      oldDelegate.positions != positions ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dashedColor != dashedColor ||
      oldDelegate.activeLineColor != activeLineColor ||
      oldDelegate.galaxy != galaxy ||
      oldDelegate.rootId != rootId ||
      oldDelegate.highlightedNodeId != highlightedNodeId ||
      oldDelegate.constellationCenters != constellationCenters;
}
