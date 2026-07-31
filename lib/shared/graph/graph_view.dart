import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../labels/label_catalog.dart';
import 'graph_models.dart';

/// Icono representativo de cada tipo de nodo, reutilizado tanto por el
/// grafo animado como por la vista de resumen en lista.
IconData iconForType(String type) {
  switch (type) {
    case 'agent':
      return Icons.smart_toy_outlined;
    case 'skill':
      return Icons.extension_outlined;
    case 'knowledge':
      return Icons.menu_book_outlined;
    case 'connection':
      return Icons.cable_outlined;
    case 'memory':
      return Icons.description_outlined;
    case 'workflow':
      return Icons.account_tree_outlined;
    case 'evaluator':
      return Icons.rule_outlined;
    default:
      return Icons.circle_outlined;
  }
}

/// Formas de ordenar automáticamente el grafo: dos variantes jerárquicas
/// (raíz arriba/izquierda y capas hacia abajo/derecha) y la original en
/// círculos concéntricos.
enum GraphSortMode { hierarchyVertical, hierarchyHorizontal, radial }

/// Controla el modo de ordenación desde fuera de [AnimatedResourceGraph]
/// (p. ej. un botón desplegable en la cabecera del diálogo, junto al
/// buscador), sin que el grafo necesite conocer ese control.
class GraphSortController extends ChangeNotifier {
  GraphSortController([this._mode = GraphSortMode.hierarchyVertical]);

  GraphSortMode _mode;
  GraphSortMode get mode => _mode;

  void setMode(GraphSortMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}

/// Grafo animado de contenido de un recurso: por defecto en capas
/// jerárquicas (raíz arriba, niveles hacia abajo) o, si se prefiere, en
/// círculos concéntricos. Sin dependencias externas (solo `CustomPaint` +
/// `AnimationController`) para no añadir un paquete de grafos solo para
/// esta vista.
class AnimatedResourceGraph extends StatefulWidget {
  const AnimatedResourceGraph({
    required this.nodes,
    required this.edges,
    required this.rootId,
    required this.quickViewDescriptionLabel,
    required this.quickViewNoDescriptionLabel,
    required this.quickViewConnectionsLabel,
    required this.quickViewNoConnectionsLabel,
    required this.quickViewCloseTooltip,
    this.emptyLabel = '',
    this.highlightQuery = '',
    this.sortController,
    super.key,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String rootId;
  final String emptyLabel;

  /// Texto de búsqueda: los nodos cuya etiqueta coincida parpadean para
  /// resaltarse, sin cambiar la vista (siempre es un grafo).
  final String highlightQuery;

  /// Permite elegir el modo de ordenación desde fuera (p. ej. un botón
  /// desplegable en la cabecera del diálogo). Si no se provee, el grafo
  /// crea y gestiona uno propio internamente.
  final GraphSortController? sortController;

  final String quickViewDescriptionLabel;
  final String quickViewNoDescriptionLabel;
  final String quickViewConnectionsLabel;
  final String quickViewNoConnectionsLabel;
  final String quickViewCloseTooltip;

  @override
  State<AnimatedResourceGraph> createState() => _AnimatedResourceGraphState();
}

class _AnimatedResourceGraphState extends State<AnimatedResourceGraph>
    with TickerProviderStateMixin {
  // Distancia entre anillos de niveles consecutivos (modo radial).
  static const _ringSpacing = 170.0;
  // Distancia entre niveles/hermanos consecutivos (modos jerárquicos).
  static const _levelSpacing = 150.0;
  static const _siblingSpacing = 130.0;
  static const _minScale = 0.4;
  static const _maxScale = 2.5;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  )..repeat(reverse: true);

  // Posiciones arrastrables por el usuario, indexadas por id de nodo. Solo se
  // calcula el layout por niveles por defecto para los nodos que aún no
  // tienen una posición manual asignada.
  final Map<String, Offset> _positions = {};

  /// Desplazamiento del lienzo dentro del visor del diálogo: arrastrando el
  /// fondo (fuera de cualquier nodo) se exploran grafos más grandes que el
  /// área visible sin mover los nodos.
  Offset _panOffset = Offset.zero;

  /// Solo se centra el lienzo la primera vez: a partir de ahí el usuario
  /// controla el desplazamiento arrastrando el fondo.
  bool _panInitialized = false;

  /// Zoom actual del lienzo: pellizco con dos dedos o rueda del ratón /
  /// trackpad, siempre centrado en el punto donde ocurre el gesto.
  double _scale = 1.0;

  // Instantánea del lienzo al iniciar un gesto de pan/pellizco, para
  // recalcular la posición sin acumular error entre fotogramas.
  Offset _gestureStartPan = Offset.zero;
  double _gestureStartScale = 1.0;
  Offset _gestureStartFocalGlobal = Offset.zero;
  Offset _gestureStartLocalFocal = Offset.zero;

  late final GraphSortController _sortController =
      widget.sortController ?? GraphSortController();
  bool get _ownsSortController => widget.sortController == null;
  GraphSortMode get _sortMode => _sortController.mode;

  @override
  void initState() {
    super.initState();
    _sortController.addListener(_handleSortModeChanged);
  }

  /// Cambiar de modo reordena desde cero: se descartan las posiciones
  /// (incluidas las arrastradas a mano) y se recentra el lienzo, ya que
  /// cada modo tiene una forma y un tamaño de lienzo muy distintos.
  void _handleSortModeChanged() {
    setState(() {
      _positions.clear();
      _panInitialized = false;
      _scale = 1.0;
    });
  }

  @override
  void dispose() {
    _sortController.removeListener(_handleSortModeChanged);
    if (_ownsSortController) _sortController.dispose();
    _entrance.dispose();
    _pulse.dispose();
    _blink.dispose();
    super.dispose();
  }

  bool _matches(GraphNode node) =>
      widget.highlightQuery.isNotEmpty &&
      node.id != widget.rootId &&
      node.label.toLowerCase().contains(widget.highlightQuery.toLowerCase());

  /// Distancia (en aristas, desde la raíz) de cada nodo: agrupa el grafo en
  /// anillos concéntricos por nivel en vez de mezclar agentes con sus
  /// propias skills/knowledge en el mismo círculo.
  Map<String, int> _computeLevels() {
    final children = <String, List<String>>{};
    for (final edge in widget.edges) {
      children.putIfAbsent(edge.sourceId, () => []).add(edge.targetId);
    }
    final levels = <String, int>{widget.rootId: 0};
    final queue = Queue<String>()..add(widget.rootId);
    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      final depth = levels[current]!;
      for (final next in children[current] ?? const <String>[]) {
        if (levels.containsKey(next)) continue;
        levels[next] = depth + 1;
        queue.add(next);
      }
    }
    // Nodo sin ruta desde la raíz (no debería ocurrir): se ubica en el
    // primer anillo para que siga siendo visible.
    for (final node in widget.nodes) {
      levels.putIfAbsent(node.id, () => 1);
    }
    return levels;
  }

  Size _canvasSizeFor(Size viewport, Map<String, int> levels) {
    if (_sortMode == GraphSortMode.radial) {
      final maxLevel = levels.values.fold(0, math.max);
      final maxRadius = maxLevel * _ringSpacing + 70;
      return Size(
        math.max(viewport.width, maxRadius * 2),
        math.max(viewport.height, maxRadius * 2),
      );
    }
    final perLevelCount = <int, int>{};
    for (final level in levels.values) {
      perLevelCount[level] = (perLevelCount[level] ?? 0) + 1;
    }
    final maxLevel = levels.values.fold(0, math.max);
    final maxPerLevel = perLevelCount.values.fold(1, math.max);
    final mainAxis = (maxLevel + 1) * _levelSpacing + 100;
    final crossAxis = maxPerLevel * _siblingSpacing + 100;
    final horizontal = _sortMode == GraphSortMode.hierarchyHorizontal;
    return Size(
      math.max(viewport.width, horizontal ? mainAxis : crossAxis),
      math.max(viewport.height, horizontal ? crossAxis : mainAxis),
    );
  }

  void _ensurePositions(Size canvasSize, Map<String, int> levels) {
    if (_positions.length == widget.nodes.length) return;
    if (_sortMode == GraphSortMode.radial) {
      _ensureRadialPositions(canvasSize, levels);
    } else {
      _ensureLayeredPositions(
        canvasSize,
        levels,
        horizontal: _sortMode == GraphSortMode.hierarchyHorizontal,
      );
    }
  }

  void _ensureRadialPositions(Size canvasSize, Map<String, int> levels) {
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final byLevel = <int, List<GraphNode>>{};
    for (final node in widget.nodes) {
      byLevel.putIfAbsent(levels[node.id] ?? 1, () => []).add(node);
    }
    for (final entry in byLevel.entries) {
      final level = entry.key;
      final nodesInLevel = entry.value;
      final radius = level * _ringSpacing;
      for (var i = 0; i < nodesInLevel.length; i++) {
        final node = nodesInLevel[i];
        if (_positions.containsKey(node.id)) continue;
        _positions[node.id] = level == 0
            ? center
            : center +
                  Offset.fromDirection(
                    (2 * math.pi * i / nodesInLevel.length) - (math.pi / 2),
                    radius,
                  );
      }
    }
  }

  /// Layout jerárquico: la raíz queda en el extremo superior (o izquierdo,
  /// en el modo horizontal) y cada nivel siguiente se dibuja como una capa
  /// más abajo (o a la derecha). Dentro de cada capa, los nodos se ordenan
  /// por la posición media de sus padres en la capa anterior (heurística
  /// de baricentro) para minimizar cruces de aristas entre capas.
  void _ensureLayeredPositions(
    Size canvasSize,
    Map<String, int> levels, {
    required bool horizontal,
  }) {
    final byLevel = <int, List<GraphNode>>{};
    for (final node in widget.nodes) {
      byLevel.putIfAbsent(levels[node.id] ?? 1, () => []).add(node);
    }
    final parentsOf = <String, List<String>>{};
    for (final edge in widget.edges) {
      parentsOf.putIfAbsent(edge.targetId, () => []).add(edge.sourceId);
    }
    final crossPosition = <String, double>{};
    final crossCenter = horizontal
        ? canvasSize.height / 2
        : canvasSize.width / 2;
    for (final level in byLevel.keys.toList()..sort()) {
      var nodesInLevel = byLevel[level]!;
      if (level > 0) {
        final indexed = nodesInLevel.asMap().entries.toList();
        indexed.sort((a, b) {
          final barycenterA = _barycenterOf(a.value, parentsOf, crossPosition);
          final barycenterB = _barycenterOf(b.value, parentsOf, crossPosition);
          final cmp = barycenterA.compareTo(barycenterB);
          return cmp != 0 ? cmp : a.key.compareTo(b.key);
        });
        nodesInLevel = [for (final entry in indexed) entry.value];
      }
      final totalSpan = (nodesInLevel.length - 1) * _siblingSpacing;
      final mainAxisPos = 80.0 + level * _levelSpacing;
      for (var i = 0; i < nodesInLevel.length; i++) {
        final node = nodesInLevel[i];
        final crossPos = nodesInLevel.length == 1
            ? crossCenter
            : crossCenter - totalSpan / 2 + i * _siblingSpacing;
        crossPosition[node.id] = crossPos;
        if (_positions.containsKey(node.id)) continue;
        _positions[node.id] = horizontal
            ? Offset(mainAxisPos, crossPos)
            : Offset(crossPos, mainAxisPos);
      }
    }
  }

  /// Posición media (en el eje transversal) de los padres ya ubicados de
  /// [node]; si no tiene padres ubicados aún, mantiene su orden original.
  double _barycenterOf(
    GraphNode node,
    Map<String, List<String>> parentsOf,
    Map<String, double> crossPosition,
  ) {
    final parentPositions = [
      for (final parentId in parentsOf[node.id] ?? const <String>[])
        ?crossPosition[parentId],
    ];
    if (parentPositions.isEmpty) {
      return widget.nodes.indexWhere((n) => n.id == node.id).toDouble();
    }
    return parentPositions.reduce((a, b) => a + b) / parentPositions.length;
  }

  Offset _clampPan(Offset offset, Size viewport, Size canvas, double scale) {
    final minDx = math.min(0.0, viewport.width - canvas.width * scale);
    final minDy = math.min(0.0, viewport.height - canvas.height * scale);
    return Offset(offset.dx.clamp(minDx, 0.0), offset.dy.clamp(minDy, 0.0));
  }

  /// Aplica un nuevo zoom manteniendo fijo el punto del lienzo que había
  /// bajo [focalGlobal] (foco del pellizco o posición del cursor), a partir
  /// de una referencia (pan/escala/foco) tomada al iniciar el gesto.
  void _applyZoom({
    required double rawNewScale,
    required Offset focalGlobal,
    required Offset startPan,
    required double startScale,
    required Offset startLocalFocal,
    required Size viewport,
    required Size canvasSize,
  }) {
    final newScale = rawNewScale.clamp(_minScale, _maxScale);
    final canvasPointUnderFocal = startLocalFocal / startScale;
    final focalDelta = focalGlobal - _gestureStartFocalGlobal;
    final newPan =
        startPan +
        focalDelta +
        canvasPointUnderFocal * (startScale - newScale);
    setState(() {
      _scale = newScale;
      _panOffset = _clampPan(newPan, viewport, canvasSize, newScale);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.length <= 1) {
      return Center(
        child: Text(
          widget.emptyLabel,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final levels = _computeLevels();
        final canvasSize = _canvasSizeFor(viewport, levels);
        _ensurePositions(canvasSize, levels);
        if (!_panInitialized) {
          _panInitialized = true;
          // Centra la cámara en el centro del lienzo (donde está la raíz)
          // en vez de mostrar su esquina superior-izquierda por defecto.
          _panOffset = Offset(
            (viewport.width - canvasSize.width) / 2,
            (viewport.height - canvasSize.height) / 2,
          );
        }
        _panOffset = _clampPan(_panOffset, viewport, canvasSize, _scale);
        final positions = [
          for (final node in widget.nodes) _positions[node.id]!,
        ];
        final scaledWidth = canvasSize.width * _scale;
        final scaledHeight = canvasSize.height * _scale;
        return Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final canvasPointUnderCursor =
                (event.localPosition - _panOffset) / _scale;
            final newScale = (_scale * math.exp(-event.scrollDelta.dy * 0.0015))
                .clamp(_minScale, _maxScale);
            final newPan =
                event.localPosition - canvasPointUnderCursor * newScale;
            setState(() {
              _scale = newScale;
              _panOffset = _clampPan(newPan, viewport, canvasSize, newScale);
            });
          },
          child: ClipRect(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Fondo: arrastrar aquí (fuera de los nodos) desplaza el
                // lienzo (pan) y pellizcar con dos dedos hace zoom, siempre
                // centrado en el punto del gesto.
                Positioned(
                  left: _panOffset.dx,
                  top: _panOffset.dy,
                  width: scaledWidth,
                  height: scaledHeight,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onScaleStart: (details) {
                      _gestureStartPan = _panOffset;
                      _gestureStartScale = _scale;
                      _gestureStartFocalGlobal = details.focalPoint;
                      _gestureStartLocalFocal = details.localFocalPoint;
                    },
                    onScaleUpdate: (details) {
                      _applyZoom(
                        rawNewScale: _gestureStartScale * details.scale,
                        focalGlobal: details.focalPoint,
                        startPan: _gestureStartPan,
                        startScale: _gestureStartScale,
                        startLocalFocal: _gestureStartLocalFocal,
                        viewport: viewport,
                        canvasSize: canvasSize,
                      );
                    },
                  ),
                ),
                AnimatedBuilder(
                  animation: Listenable.merge([_entrance, _pulse, _blink]),
                  builder: (context, _) {
                    return Positioned(
                      left: _panOffset.dx,
                      top: _panOffset.dy,
                      width: scaledWidth,
                      height: scaledHeight,
                      child: Transform.scale(
                        scale: _scale,
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: canvasSize.width,
                          height: canvasSize.height,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IgnorePointer(
                                child: CustomPaint(
                                  size: canvasSize,
                                  painter: _GraphEdgePainter(
                                    nodes: widget.nodes,
                                    edges: widget.edges,
                                    positions: positions,
                                    progress: Curves.easeOutCubic.transform(
                                      _entrance.value,
                                    ),
                                  ),
                                ),
                              ),
                              for (var i = 0; i < widget.nodes.length; i++)
                                _buildNode(context, i, positions, canvasSize),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNode(
    BuildContext context,
    int index,
    List<Offset> positions,
    Size canvasSize,
  ) {
    final node = widget.nodes[index];
    final isRoot = node.id == widget.rootId;
    final pos = positions[index];
    final stagger = Interval(
      (index / widget.nodes.length) * 0.5,
      ((index / widget.nodes.length) * 0.5) + 0.5,
      curve: Curves.easeOutBack,
    );
    final t = stagger.transform(_entrance.value).clamp(0.0, 1.0);
    final pulse = isRoot ? (1 + _pulse.value * 0.06) : 1.0;
    final color = labelColor(node.type);
    final diameter = isRoot ? 72.0 : 54.0;
    final isMatch = _matches(node);
    final blinkOpacity = isMatch ? (0.35 + 0.65 * _blink.value) : 1.0;

    return Positioned(
      left: pos.dx - 46,
      top: pos.dy - 46,
      width: 92,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _showQuickView(context, node),
          onPanUpdate: (details) {
            setState(() {
              final updated = pos + details.delta / _scale;
              _positions[node.id] = Offset(
                updated.dx.clamp(30.0, math.max(30.0, canvasSize.width - 30.0)),
                updated.dy.clamp(
                  30.0,
                  math.max(30.0, canvasSize.height - 30.0),
                ),
              );
            });
          },
          child: Opacity(
            opacity: t,
            child: Transform.scale(
              scale: (0.4 + 0.6 * t) * pulse,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: blinkOpacity,
                    child: Container(
                      width: diameter,
                      height: diameter,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.45),
                            blurRadius: isRoot ? 18 : 8,
                          ),
                          if (isMatch)
                            BoxShadow(
                              color: Colors.amber.withValues(alpha: 0.7),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        iconForType(node.type),
                        color: Colors.white,
                        size: isRoot ? 30 : 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    node.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isRoot ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Vista rápida de un nodo: icono/color/etiqueta y con qué otros nodos
  /// conecta (entrantes y salientes), sin salir del grafo.
  void _showQuickView(BuildContext context, GraphNode node) {
    final connectedIds = <String>{
      for (final edge in widget.edges)
        if (edge.sourceId == node.id) edge.targetId,
      for (final edge in widget.edges)
        if (edge.targetId == node.id) edge.sourceId,
    };
    final connectedNodes = [
      for (final other in widget.nodes)
        if (connectedIds.contains(other.id)) other,
    ];
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: labelColor(node.type),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                iconForType(node.type),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(node.label, overflow: TextOverflow.ellipsis)),
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: widget.quickViewCloseTooltip,
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.quickViewDescriptionLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                node.description.isEmpty
                    ? widget.quickViewNoDescriptionLabel
                    : node.description,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                widget.quickViewConnectionsLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (connectedNodes.isEmpty)
                Text(
                  widget.quickViewNoConnectionsLabel,
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                )
              else
                for (final connected in connectedNodes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          iconForType(connected.type),
                          size: 16,
                          color: labelColor(connected.type),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            connected.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GraphEdgePainter extends CustomPainter {
  _GraphEdgePainter({
    required this.nodes,
    required this.edges,
    required this.positions,
    required this.progress,
  });

  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final List<Offset> positions;
  final double progress;

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
        ..color = (edge.dashed ? Colors.orange : Colors.grey).withValues(
          alpha: 0.55,
        )
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
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges;
}
