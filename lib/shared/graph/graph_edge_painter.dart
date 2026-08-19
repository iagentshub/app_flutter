import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import 'graph_models.dart';

/// Caché de los caminos de las aristas, con su clave de invalidación.
///
/// Vive en el `State` y no en el pintor porque el pintor se reconstruye en
/// cada fotograma: un campo suyo no sobreviviría de un repintado al
/// siguiente. Es el único estado que el pintor toca, y solo para no
/// recalcular curva a curva una geometría que no ha cambiado — el caso del
/// ratón por encima, que cambia el color de las aristas pero ninguna
/// posición.
class GraphEdgePathCache {
  List<GraphEdge>? _edges;
  Map<String, Offset>? _positions;
  bool? _galaxy;
  List<_EdgePath>? _paths;

  List<_EdgePath> _resolve(
    List<GraphEdge> edges,
    Map<String, Offset> positions,
    bool galaxy,
    List<_EdgePath> Function() build,
  ) {
    final cached = _paths;
    if (cached != null &&
        _galaxy == galaxy &&
        identical(_edges, edges) &&
        mapEquals(_positions, positions)) {
      return cached;
    }
    _edges = edges;
    _positions = positions;
    _galaxy = galaxy;
    return _paths = build();
  }
}

/// Una arista con su camino ya trazado.
class _EdgePath {
  const _EdgePath(this.edge, this.path);

  final GraphEdge edge;
  final Path path;
}

/// Pinta las aristas del grafo animado: líneas rectas (con progreso de
/// entrada) o discontinuas para las conexiones marcadas como `dashed` (p.
/// ej. un bucle en una orquestación).
class GraphEdgePainter extends CustomPainter {
  GraphEdgePainter({
    required this.edges,
    required this.positions,
    required this.progress,
    required this.cache,
    this.lineColor = FncColors.materialGrey,
    this.dashedColor = FncColors.materialOrange,
    this.activeLineColor = FncColors.galaxyEdgeActive,
    this.galaxy = false,
    this.highlightedNodeId,
  });

  final List<GraphEdge> edges;

  /// Posición de cada nodo por id. Era una lista paralela a `nodes` y
  /// resolver un extremo costaba un `indexWhere` — dos recorridos completos
  /// por arista y por repintado, que con 500 nodos se medían en 0,77 ms de
  /// un presupuesto de 16 ms. El mapa lo deja en O(1).
  final Map<String, Offset> positions;
  final double progress;

  /// Caché de caminos, propiedad del `State`. Ver [GraphEdgePathCache].
  final GraphEdgePathCache cache;

  /// Color de las aristas normales/discontinuas. Ya incluye la opacidad
  /// deseada: el pintor no aplica ninguna adicional, para que el modo
  /// galaxia pueda usar líneas más tenues sobre su fondo oscuro.
  final Color lineColor;
  final Color dashedColor;
  final Color activeLineColor;
  final bool galaxy;
  final String? highlightedNodeId;

  List<_EdgePath> _edgePaths() => cache._resolve(edges, positions, galaxy, () {
    final result = <_EdgePath>[];
    for (final edge in edges) {
      final start = positions[edge.sourceId];
      final end = positions[edge.targetId];
      if (start == null || end == null) continue;
      result.add(
        _EdgePath(
          edge,
          galaxy ? _galaxyPath(edge, start, end) : _linePath(start, end),
        ),
      );
    }
    return result;
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fraction = progress.clamp(0.0, 1.0);
    for (final entry in _edgePaths()) {
      final edge = entry.edge;
      final visiblePath = _visiblePath(entry.path, fraction);
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

  /// Curva suave y consistente para todas las aristas. La que salía de la
  /// raíz pasaba antes por el centro de la constelación del otro extremo —el
  /// agrupamiento por tipo—, que ya no existe: ahora lo que agrupa es la
  /// dependencia, y la arista une los dos nodos y nada más.
  Path _galaxyPath(GraphEdge edge, Offset start, Offset end) {
    final path = Path()..moveTo(start.dx, start.dy);
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

  /// Recortar el camino solo tiene sentido mientras entra. Con la animación
  /// terminada —el estado normal todo el tiempo que el grafo está abierto—
  /// `computeMetrics()` + `extractPath()` reconstruían cada curva para no
  /// quitarle nada.
  Path _visiblePath(Path path, double fraction) {
    if (fraction >= 1) return path;
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

  /// Por contenido, no por identidad de las colecciones: el `build` las
  /// recrea en cada `setState` (arrastre, rueda, ratón por encima), así que
  /// comparar referencias daba `true` siempre que se tocaba el grafo. Las
  /// posiciones se comparan una a una a propósito —`_positions` se muta en
  /// el sitio al arrastrar un nodo—: con identidad, la arista se quedaba
  /// clavada donde estaba.
  @override
  bool shouldRepaint(covariant GraphEdgePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.galaxy != galaxy ||
      oldDelegate.highlightedNodeId != highlightedNodeId ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dashedColor != dashedColor ||
      oldDelegate.activeLineColor != activeLineColor ||
      !identical(oldDelegate.edges, edges) ||
      !mapEquals(oldDelegate.positions, positions);
}
