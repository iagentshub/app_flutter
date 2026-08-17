import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';
import '../labels/label_catalog.dart';
import 'galaxy_background_painter.dart';
import 'galaxy_constellation_painter.dart';
import 'galaxy_layout.dart';
import 'graph_edge_painter.dart';
import 'graph_models.dart';
import 'graph_sort_controller.dart';

/// Icono representativo de cada tipo de nodo, reutilizado tanto por el
/// grafo animado como por la vista de resumen en lista.
IconData iconForType(String type) {
  switch (type) {
    case 'agent':
      return Icons.smart_toy_outlined;
    case 'skill':
      return Icons.extension_outlined;
    case 'prompt':
      return Icons.bolt_outlined;
    case 'tool':
      return Icons.build_outlined;
    case 'knowledge':
      return Icons.menu_book_outlined;
    case 'connection':
      return Icons.cable_outlined;
    case 'provider':
      return Icons.hub_outlined;
    case 'official_source':
      return Icons.account_tree_outlined;
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
    this.showLabels = true,
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

  /// Si es falso, se ocultan las etiquetas de texto bajo cada nodo (salvo
  /// las que coincidan con [highlightQuery]) para despejar grafos grandes.
  /// A diferencia de [sortController], cambiar este valor no reordena ni
  /// reinicia el lienzo: solo afecta al texto.
  final bool showLabels;

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
  // Distancia entre niveles/hermanos consecutivos (modos jerárquicos).
  static const _levelSpacing = 150.0;
  static const _siblingSpacing = 130.0;
  // Zoom mínimo habitual y tope absoluto de alejamiento: un grafo grande
  // necesita alejarse más de lo normal para verse entero (ver
  // [_minScaleFor]), pero nunca tanto como para volverse ilegible.
  static const _minScaleDefault = 0.4;
  static const _minScaleFloor = 0.1;
  static const _maxScale = 4.0;
  // La vista inicial nunca arranca más alejada que esto: un "fit to view"
  // sin piso, con un lienzo mucho más grande que el visor, deja los
  // nodos diminutos y todo apretado desde el primer vistazo. Se prefiere
  // ver el núcleo con buen detalle y dejar el resto para explorar
  // moviéndose y haciendo zoom, no forzar ver el grafo entero de entrada.
  static const _initialFitFloor = 0.55;

  // --- Modo galaxia (layout de fuerzas) ---
  // Área objetivo (px²) por nodo: controla la densidad de puntos del
  // lienzo a medida que crece el grafo.
  static const _galaxyPerNodeArea = 8000.0;
  // El lienzo del modo galaxia siempre es al menos esto de grande respecto
  // al visor, aunque el grafo tenga pocos nodos: sin este mínimo, un
  // grafo que ya "cabe" deja el lienzo del mismo tamaño que la pantalla y
  // no queda espacio real para explorar con zoom/pan, aunque se calcule
  // un "fit to view" — sencillamente no hay hacia dónde desplazarse. Un
  // factor bajo también deja los nodos apretados contra el borde del
  // visor, dando sensación de "límite" en vez de espacio para moverse.
  static const _galaxyMinCanvasFactor = 3.2;
  // Factor sobre la distancia ideal k = factor * sqrt(área / n).
  static const _galaxyIdealLengthFactor = 1.0;
  // Atracción uniforme de todos los nodos hacia el centro: con cientos de
  // nodos, la suma de repulsiones que recibe cada uno (una por cada otro
  // nodo del grafo) casi nunca se cancela del todo, y esa resultante neta
  // crece con el tamaño del grafo. Sin una gravedad que la contrarreste
  // con fuerza suficiente, los nodos acaban empujados hasta el borde del
  // lienzo (donde el clamp los deja alineados en fila, nada orgánico).
  static const _galaxyGravity = 0.06;
  static const _galaxyClusterGravity = 0.14;
  // Semilla fija: reabrir el mismo recurso reproduce el mismo layout.
  static const _galaxySeed = 20260804;

  // Se crean en `initState`, no como inicializadores `late` perezosos: con
  // un grafo de un solo nodo (raíz sin hijos) `build()` corta antes de
  // llegar al `AnimatedBuilder` que los usa (ver el `if` al inicio de
  // `build`), así que nunca se tocaban — hasta que `dispose()` los
  // alcanzaba primero e inicializaba un `AnimationController` nuevo sobre
  // un `State` ya desactivado, lo que lanzaba
  // "Looking up a deactivated widget's ancestor is unsafe.".
  late final AnimationController _entrance;
  late final AnimationController _pulse;
  late final AnimationController _blink;

  /// Ventana en primer plano. Con la app oculta no hay nada que animar.
  bool _appVisible = true;
  bool _reduceMotion = false;
  late final AppLifecycleListener _lifecycle;

  // Posiciones arrastrables por el usuario, indexadas por id de nodo. Solo se
  // calcula el layout por niveles por defecto para los nodos que aún no
  // tienen una posición manual asignada.
  final Map<String, Offset> _positions = {};
  final Set<String> _draggedNodeIds = {};
  bool _galaxyLayoutPending = false;
  int _galaxyLayoutGeneration = 0;
  Size? _galaxyLayoutSize;
  String? _galaxyLayoutFingerprint;
  final Map<String, FocusNode> _nodeFocusNodes = {};
  String? _focusedNodeId;
  String? _hoveredNodeId;

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
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        _appVisible = state == AppLifecycleState.resumed;
        _syncRepeatingAnimations();
      },
    );
    _sortController.addListener(_handleSortModeChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion != reduceMotion) _reduceMotion = reduceMotion;
    if (_reduceMotion) _entrance.value = 1;
    _syncRepeatingAnimations();
  }

  /// El grafo se abre desde cada tarjeta en un diálogo a pantalla completa y
  /// sus dos animaciones cíclicas no paraban nunca mientras estuviera montado:
  /// la app no llegaba a un frame en reposo, lo que en web mantiene vivo el
  /// requestAnimationFrame y en portátil o móvil se nota en la batería.
  ///
  /// El pulso solo hace falta con la ventana en primer plano, y el parpadeo
  /// además solo cuando hay una búsqueda que resaltar.
  void _syncRepeatingAnimations() {
    final animate = _appVisible && !_reduceMotion;
    _sync(_pulse, activa: animate);
    _sync(_blink, activa: animate && widget.highlightQuery.isNotEmpty);
  }

  void _sync(AnimationController controller, {required bool activa}) {
    if (activa) {
      if (!controller.isAnimating) controller.repeat(reverse: true);
    } else if (controller.isAnimating) {
      controller.stop();
    }
  }

  @visibleForTesting
  bool get debugPulseAnimating => _pulse.isAnimating;

  @visibleForTesting
  bool get debugBlinkAnimating => _blink.isAnimating;

  @visibleForTesting
  bool get debugEntranceCompleted => _entrance.value == 1;

  @visibleForTesting
  bool get debugGalaxyLayoutPending => _galaxyLayoutPending;

  @visibleForTesting
  String? get debugHighlightedNodeId => _focusedNodeId ?? _hoveredNodeId;

  @visibleForTesting
  Offset? debugPositionFor(String nodeId) => _positions[nodeId];

  /// Cambiar de modo reordena desde cero: se descartan las posiciones
  /// (incluidas las arrastradas a mano) y se recentra el lienzo, ya que
  /// cada modo tiene una forma y un tamaño de lienzo muy distintos.
  void _handleSortModeChanged() {
    setState(() {
      _galaxyLayoutGeneration++;
      _galaxyLayoutPending = false;
      _galaxyLayoutSize = null;
      _galaxyLayoutFingerprint = null;
      _positions.clear();
      _draggedNodeIds.clear();
      _panInitialized = false;
      _scale = 1.0;
    });
  }

  @override
  void dispose() {
    _sortController.removeListener(_handleSortModeChanged);
    if (_ownsSortController) _sortController.dispose();
    _lifecycle.dispose();
    _entrance.dispose();
    _pulse.dispose();
    _blink.dispose();
    for (final focusNode in _nodeFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedResourceGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlightQuery != widget.highlightQuery) {
      _syncRepeatingAnimations();
    }
    final currentIds = widget.nodes.map((node) => node.id).toSet();
    final oldFingerprint = _fingerprintFor(
      oldWidget.nodes,
      oldWidget.edges,
      oldWidget.rootId,
    );
    final currentFingerprint = _fingerprintFor(
      widget.nodes,
      widget.edges,
      widget.rootId,
    );
    if (oldFingerprint != currentFingerprint) {
      _galaxyLayoutGeneration++;
      _galaxyLayoutPending = false;
      _galaxyLayoutSize = null;
      _galaxyLayoutFingerprint = null;
      _positions.removeWhere((id, _) => !currentIds.contains(id));
      _draggedNodeIds.removeWhere((id) => !currentIds.contains(id));
    }
    final removedIds = _nodeFocusNodes.keys
        .where((id) => !currentIds.contains(id))
        .toList();
    for (final id in removedIds) {
      _nodeFocusNodes.remove(id)?.dispose();
      if (_focusedNodeId == id) _focusedNodeId = null;
    }
  }

  FocusNode _focusNodeFor(GraphNode node) => _nodeFocusNodes.putIfAbsent(
    node.id,
    () => FocusNode(debugLabel: 'graph-node:${node.id}'),
  );

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
    if (_sortMode == GraphSortMode.galaxy) {
      // Área objetivo proporcional al número de nodos, con el mismo
      // aspecto que el viewport (un layout de fuerzas no tiene un eje
      // principal como los modos jerárquicos), para mantener una densidad
      // de puntos razonable tanto con 60 como con 500+ nodos.
      final targetArea = widget.nodes.length * _galaxyPerNodeArea;
      final aspect = viewport.width / viewport.height;
      final height = math.sqrt(targetArea / aspect);
      final width = height * aspect;
      final minCanvasFactor = widget.nodes.length <= 20
          ? 1.6
          : widget.nodes.length <= 60
          ? 2.2
          : _galaxyMinCanvasFactor;
      return Size(
        math.max(viewport.width * minCanvasFactor, width),
        math.max(viewport.height * minCanvasFactor, height),
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
    if (_sortMode == GraphSortMode.galaxy) {
      _ensureGalaxyPositions(canvasSize);
    } else {
      if (_positions.length == widget.nodes.length) return;
      _ensureLayeredPositions(
        canvasSize,
        levels,
        horizontal: _sortMode == GraphSortMode.hierarchyHorizontal,
      );
    }
  }

  /// Cuántas iteraciones de la simulación de fuerzas correr según el
  /// tamaño del grafo: menos nodos permiten más iteraciones (layout más
  /// asentado) sin arriesgar un frame lento con grafos de cientos de nodos.
  int _galaxyIterationsFor(int n) {
    if (n <= 60) return 300;
    if (n <= 150) return 220;
    if (n <= 300) return 150;
    return 90;
  }

  String _fingerprintFor(
    List<GraphNode> nodes,
    List<GraphEdge> edges,
    String rootId,
  ) =>
      '$rootId|${nodes.map((node) => node.id).join('|')}|'
      '${edges.map((edge) => '${edge.sourceId}>${edge.targetId}').join('|')}';

  /// Prepara posiciones iniciales baratas durante el build y difiere la
  /// simulación de fuerzas hasta después del frame. La simulación cede el
  /// isolate entre lotes en grafos grandes: funciona tanto en web como en
  /// nativo y evita un único bloqueo de millones de pares en el build.
  void _ensureGalaxyPositions(Size canvasSize) {
    final n = widget.nodes.length;
    if (n == 0) return;

    final fingerprint = _fingerprintFor(
      widget.nodes,
      widget.edges,
      widget.rootId,
    );
    if (_galaxyLayoutPending) return;
    if (_positions.length == n &&
        _galaxyLayoutFingerprint == fingerprint &&
        _galaxyLayoutSize == canvasSize) {
      return;
    }

    final ids = [for (final node in widget.nodes) node.id];
    final rootIndex = ids.indexOf(widget.rootId);
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final constellationCenters = GalaxyLayout.centersFor(
      nodes: widget.nodes,
      rootId: widget.rootId,
      canvasSize: canvasSize,
    );
    final random = math.Random(_galaxySeed);
    final existingIds = _galaxyLayoutFingerprint == fingerprint
        ? <String>{..._draggedNodeIds}
        : <String>{..._positions.keys, ..._draggedNodeIds};
    final seedRadius = math.min(canvasSize.width, canvasSize.height) * 0.11;
    for (var i = 0; i < n; i++) {
      if (_positions.containsKey(ids[i])) continue;
      if (i == rootIndex) {
        _positions[ids[i]] = center;
        continue;
      }
      final node = widget.nodes[i];
      final clusterCenter =
          constellationCenters[GalaxyLayout.constellationKey(node.type)] ??
          center;
      final angle = random.nextDouble() * 2 * math.pi;
      final radius = seedRadius * math.sqrt(random.nextDouble());
      _positions[ids[i]] = Offset(
        clusterCenter.dx + radius * math.cos(angle),
        clusterCenter.dy + radius * math.sin(angle),
      );
    }

    final generation = ++_galaxyLayoutGeneration;
    _galaxyLayoutPending = true;
    _galaxyLayoutSize = canvasSize;
    _galaxyLayoutFingerprint = fingerprint;
    final initialPositions = Map<String, Offset>.of(_positions);
    final nodes = List<GraphNode>.of(widget.nodes);
    final edges = List<GraphEdge>.of(widget.edges);
    final rootId = widget.rootId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _galaxyLayoutGeneration) return;
      unawaited(
        _calculateGalaxyPositions(
          nodes: nodes,
          edges: edges,
          rootId: rootId,
          canvasSize: canvasSize,
          initialPositions: initialPositions,
          pinnedIds: existingIds,
          constellationCenters: constellationCenters,
          generation: generation,
        ),
      );
    });
  }

  Future<void> _calculateGalaxyPositions({
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required String rootId,
    required Size canvasSize,
    required Map<String, Offset> initialPositions,
    required Set<String> pinnedIds,
    required Map<String, Offset> constellationCenters,
    required int generation,
  }) async {
    final n = nodes.length;
    final ids = [for (final node in nodes) node.id];
    final rootIndex = ids.indexOf(rootId);
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final random = math.Random(_galaxySeed);
    final px = [for (final id in ids) initialPositions[id]!.dx];
    final py = [for (final id in ids) initialPositions[id]!.dy];
    final pinned = [
      for (var i = 0; i < n; i++) i == rootIndex || pinnedIds.contains(ids[i]),
    ];

    final idIndex = {for (var i = 0; i < n; i++) ids[i]: i};
    final edgesIdx = [
      for (final edge in edges)
        if (idIndex.containsKey(edge.sourceId) &&
            idIndex.containsKey(edge.targetId))
          (idIndex[edge.sourceId]!, idIndex[edge.targetId]!),
    ];

    final area = canvasSize.width * canvasSize.height;
    final k = (_galaxyIdealLengthFactor * math.sqrt(area / n)).clamp(
      72.0,
      180.0,
    );
    final iterations = _galaxyIterationsFor(n);
    final t0 = math.max(canvasSize.width, canvasSize.height) * 0.05;
    final dispX = List<double>.filled(n, 0);
    final dispY = List<double>.filled(n, 0);
    final yieldEvery = n > 300
        ? 1
        : n > 150
        ? 2
        : n > 60
        ? 4
        : iterations;

    for (var iter = 0; iter < iterations; iter++) {
      dispX.fillRange(0, n, 0);
      dispY.fillRange(0, n, 0);

      // Repulsión entre todos los pares.
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          var dx = px[i] - px[j];
          var dy = py[i] - py[j];
          var dist = math.sqrt(dx * dx + dy * dy);
          if (dist < 0.01) {
            final angle = random.nextDouble() * 2 * math.pi;
            dx = math.cos(angle) * 0.01;
            dy = math.sin(angle) * 0.01;
            dist = 0.01;
          }
          final force = (k * k) / dist;
          final ux = dx / dist * force;
          final uy = dy / dist * force;
          dispX[i] += ux;
          dispY[i] += uy;
          dispX[j] -= ux;
          dispY[j] -= uy;
        }
      }

      // Atracción a lo largo de cada arista.
      for (final (a, b) in edgesIdx) {
        final dx = px[a] - px[b];
        final dy = py[a] - py[b];
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 0.01) continue;
        final force = (dist * dist) / k;
        final ux = dx / dist * force;
        final uy = dy / dist * force;
        dispX[a] -= ux;
        dispY[a] -= uy;
        dispX[b] += ux;
        dispY[b] += uy;
      }

      // La gravedad global mantiene el conjunto dentro del observatorio. Una
      // atracción adicional hacia el centro virtual de cada tipo forma
      // constelaciones legibles sin alterar las aristas reales.
      for (var i = 0; i < n; i++) {
        final clusterCenter = i == rootIndex
            ? center
            : constellationCenters[GalaxyLayout.constellationKey(
                    nodes[i].type,
                  )] ??
                  center;
        dispX[i] += (center.dx - px[i]) * (_galaxyGravity * 0.35);
        dispY[i] += (center.dy - py[i]) * (_galaxyGravity * 0.35);
        dispX[i] += (clusterCenter.dx - px[i]) * _galaxyClusterGravity;
        dispY[i] += (clusterCenter.dy - py[i]) * _galaxyClusterGravity;
      }

      // Aplica el desplazamiento, acotado por la "temperatura" (cooling
      // lineal) y por los bordes del lienzo.
      final temperature = t0 * (1 - iter / iterations);
      for (var i = 0; i < n; i++) {
        if (pinned[i]) continue;
        final len = math.sqrt(dispX[i] * dispX[i] + dispY[i] * dispY[i]);
        if (len < 0.001) continue;
        final capped = math.min(len, temperature) / len;
        px[i] = (px[i] + dispX[i] * capped).clamp(
          30.0,
          math.max(30.0, canvasSize.width - 30.0),
        );
        py[i] = (py[i] + dispY[i] * capped).clamp(
          30.0,
          math.max(30.0, canvasSize.height - 30.0),
        );
      }

      if ((iter + 1) % yieldEvery == 0 && iter + 1 < iterations) {
        await SchedulerBinding.instance.endOfFrame;
        if (!mounted ||
            generation != _galaxyLayoutGeneration ||
            _sortMode != GraphSortMode.galaxy) {
          return;
        }
      }
    }

    if (!mounted ||
        generation != _galaxyLayoutGeneration ||
        _sortMode != GraphSortMode.galaxy) {
      return;
    }
    setState(() {
      for (var i = 0; i < n; i++) {
        if (!_draggedNodeIds.contains(ids[i])) {
          _positions[ids[i]] = Offset(px[i], py[i]);
        }
      }
      _galaxyLayoutPending = false;
    });
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

  /// Cuando el lienzo escalado es más grande que el visor (el caso más
  /// común), el pan solo puede ser negativo o cero, como antes: no debe
  /// quedar hueco visible más allá del lienzo. Pero tras un zoom-out que
  /// deja el lienzo más pequeño que el visor en algún eje (grafos que
  /// caben de sobra, o el "fit to view" inicial ver [!_panInitialized]),
  /// también debe poder ser positivo para centrarlo, en vez de pegarlo
  /// siempre a la esquina superior-izquierda.
  Offset _clampPan(Offset offset, Size viewport, Size canvas, double scale) {
    final scaledWidth = canvas.width * scale;
    final scaledHeight = canvas.height * scale;
    // En modo galaxia se permite pasear bastante más allá del lienzo (el
    // fondo cubre todo el visor de todas formas, así que no hay ningún
    // "borde" visible que romper): sin este margen extra, el pan se
    // siente topado contra un muro duro justo al llegar al final de las
    // estrellas, en vez de invitar a seguir explorando.
    final extraMargin = _sortMode == GraphSortMode.galaxy
        ? math.max(viewport.width, viewport.height) * 2.5
        : 0.0;
    final minDx = math.min(0.0, viewport.width - scaledWidth) - extraMargin;
    final minDy = math.min(0.0, viewport.height - scaledHeight) - extraMargin;
    final maxDx = math.max(0.0, viewport.width - scaledWidth) + extraMargin;
    final maxDy = math.max(0.0, viewport.height - scaledHeight) + extraMargin;
    return Offset(offset.dx.clamp(minDx, maxDx), offset.dy.clamp(minDy, maxDy));
  }

  /// Zoom mínimo permitido: normalmente [_minScaleDefault], pero un lienzo
  /// grande (grafo de cientos de nodos, sobre todo en modo galaxia) puede
  /// necesitar alejarse más que eso para verse completo de un vistazo, así
  /// que el mínimo se relaja hasta el "fit to view" exacto (acotado por
  /// [_minScaleFloor] para no volverlo ilegible).
  double _minScaleFor(Size viewport, Size canvasSize) {
    final fitScale = math.min(
      viewport.width / canvasSize.width,
      viewport.height / canvasSize.height,
    );
    return math.min(_minScaleDefault, fitScale).clamp(_minScaleFloor, 1.0);
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
    final newScale = rawNewScale.clamp(
      _minScaleFor(viewport, canvasSize),
      _maxScale,
    );
    final canvasPointUnderFocal = startLocalFocal / startScale;
    final focalDelta = focalGlobal - _gestureStartFocalGlobal;
    final newPan =
        startPan + focalDelta + canvasPointUnderFocal * (startScale - newScale);
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
    final isGalaxy = _sortMode == GraphSortMode.galaxy;
    return ColoredBox(
      color: isGalaxy ? FncColors.galaxyDeep : FncColors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = Size(constraints.maxWidth, constraints.maxHeight);
          final levels = _computeLevels();
          final canvasSize = _canvasSizeFor(viewport, levels);
          _ensurePositions(canvasSize, levels);
          if (!_panInitialized) {
            _panInitialized = true;
            // Encuadre inicial: si el lienzo es más grande que el visor
            // (grafos grandes, muy habitual en modo galaxia), arranca algo
            // alejado para no mostrar recortada una esquina al 100% de
            // zoom, pero sin forzar ver el lienzo entero de golpe (eso deja
            // los nodos diminutos y todo apretado): [_initialFitFloor] pone
            // un piso a ese alejamiento inicial. El resto del lienzo queda
            // para explorar moviéndose y haciendo zoom manualmente, hasta
            // [_minScaleFor] si se quiere ver el conjunto completo. Nunca
            // acerca (scale > 1) grafos pequeños que ya caben de sobra.
            final fitScale = math
                .min(
                  1.0,
                  math.min(
                    viewport.width / canvasSize.width,
                    viewport.height / canvasSize.height,
                  ),
                )
                .clamp(_initialFitFloor, _maxScale);
            _scale = fitScale;
            // Centra la cámara en el centro del lienzo (donde está la raíz).
            _panOffset = Offset(
              (viewport.width - canvasSize.width * fitScale) / 2,
              (viewport.height - canvasSize.height * fitScale) / 2,
            );
          }
          _panOffset = _clampPan(_panOffset, viewport, canvasSize, _scale);
          final positions = [
            for (final node in widget.nodes) _positions[node.id]!,
          ];
          final constellationCenters = isGalaxy
              ? GalaxyLayout.centersFor(
                  nodes: widget.nodes,
                  rootId: widget.rootId,
                  canvasSize: canvasSize,
                )
              : const <String, Offset>{};
          final nodeDegrees = <String, int>{
            for (final node in widget.nodes) node.id: 0,
          };
          for (final edge in widget.edges) {
            nodeDegrees.update(
              edge.sourceId,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
            nodeDegrees.update(
              edge.targetId,
              (value) => value + 1,
              ifAbsent: () => 1,
            );
          }
          final highlightedNodeId = _focusedNodeId ?? _hoveredNodeId;
          final emphasizedNodeIds = <String>{};
          if (highlightedNodeId != null) {
            emphasizedNodeIds.add(highlightedNodeId);
            for (final edge in widget.edges) {
              if (edge.sourceId == highlightedNodeId) {
                emphasizedNodeIds.add(edge.targetId);
              }
              if (edge.targetId == highlightedNodeId) {
                emphasizedNodeIds.add(edge.sourceId);
              }
            }
          }
          final scaledWidth = canvasSize.width * _scale;
          final scaledHeight = canvasSize.height * _scale;
          return Listener(
            onPointerSignal: (event) {
              if (event is! PointerScrollEvent) return;
              final canvasPointUnderCursor =
                  (event.localPosition - _panOffset) / _scale;
              final newScale =
                  (_scale * math.exp(-event.scrollDelta.dy * 0.0015)).clamp(
                    _minScaleFor(viewport, canvasSize),
                    _maxScale,
                  );
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
                  if (isGalaxy)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(painter: GalaxyBackgroundPainter()),
                      ),
                    ),
                  // Fondo: arrastrar aquí (fuera de los nodos) desplaza el
                  // lienzo (pan) y pellizcar con dos dedos hace zoom, siempre
                  // centrado en el punto del gesto. Cubre todo el visor, no
                  // solo el rectángulo del lienzo escalado: tras un "fit to
                  // view" que no llena el visor entero (letterboxing), el
                  // pan debe poder iniciarse igual desde el margen vacío.
                  Positioned.fill(
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
                                if (isGalaxy)
                                  IgnorePointer(
                                    child: CustomPaint(
                                      size: canvasSize,
                                      painter: GalaxyConstellationPainter(
                                        nodes: widget.nodes,
                                        rootId: widget.rootId,
                                        centers: constellationCenters,
                                      ),
                                    ),
                                  ),
                                IgnorePointer(
                                  child: CustomPaint(
                                    size: canvasSize,
                                    painter: GraphEdgePainter(
                                      nodes: widget.nodes,
                                      edges: widget.edges,
                                      positions: positions,
                                      progress: Curves.easeOutCubic.transform(
                                        _entrance.value,
                                      ),
                                      lineColor: isGalaxy
                                          ? FncColors.galaxyEdge
                                          : FncColors.materialGrey,
                                      dashedColor: isGalaxy
                                          ? FncColors.materialOrangeAccent
                                                .withValues(alpha: 0.35)
                                          : FncColors.materialOrange,
                                      activeLineColor:
                                          FncColors.galaxyEdgeActive,
                                      galaxy: isGalaxy,
                                      rootId: widget.rootId,
                                      highlightedNodeId: highlightedNodeId,
                                      constellationCenters:
                                          constellationCenters,
                                    ),
                                  ),
                                ),
                                for (var i = 0; i < widget.nodes.length; i++)
                                  _buildNode(
                                    context,
                                    i,
                                    positions,
                                    canvasSize,
                                    nodeDegrees,
                                    highlightedNodeId,
                                    emphasizedNodeIds,
                                  ),
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
      ),
    );
  }

  Widget _buildNode(
    BuildContext context,
    int index,
    List<Offset> positions,
    Size canvasSize,
    Map<String, int> nodeDegrees,
    String? highlightedNodeId,
    Set<String> emphasizedNodeIds,
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
    final isMatch = _matches(node);
    final isFocused = _focusedNodeId == node.id;
    final isHovered = _hoveredNodeId == node.id;
    final blinkOpacity = isMatch ? (0.35 + 0.65 * _blink.value) : 1.0;
    final focusColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? FncColors.white
        : FncColors.materialBlack;

    void openQuickView() => _showQuickView(context, node);

    final isGalaxy = _sortMode == GraphSortMode.galaxy;
    final showLabel =
        widget.showLabels || isMatch || (isGalaxy && (isHovered || isFocused));
    final isContextNode =
        highlightedNodeId == null || emphasizedNodeIds.contains(node.id);
    // El círculo/punto es el primer hijo del Column de abajo, así que su
    // centro debe coincidir exactamente con `pos` (donde termina la
    // arista dibujada por `GraphEdgePainter`): un offset fijo pensado
    // para el nodo grande del modo jerárquico (72/54px) deja la línea
    // notoriamente corta contra los puntos pequeños de la galaxia
    // (8-26px), así que se calcula según el diámetro real de cada nodo.
    final diameter = _nodeDiameter(
      node,
      isRoot: isRoot,
      isGalaxy: isGalaxy,
      degree: nodeDegrees[node.id] ?? 0,
    );
    // El área táctil (invisible) de cada nodo: 92px de ancho tiene sentido
    // para los círculos grandes del modo jerárquico (72/54px) con su
    // etiqueta siempre visible debajo, pero con los puntos diminutos de
    // la galaxia (8-26px) y las etiquetas ocultas por defecto, esa misma
    // área tan generosa hace que cientos de nodos dispersos se solapen
    // entre sí y tapen casi todo el espacio "vacío": el usuario intenta
    // arrastrar el fondo para mover la cámara y termina moviendo un nodo
    // individual por accidente. Se ajusta al tamaño real del punto salvo
    // que haya texto visible debajo, que sigue necesitando ese ancho.
    final hitboxWidth = (isGalaxy && !showLabel)
        ? math.max(diameter + 18, 34.0)
        : 92.0;

    return Positioned(
      left: pos.dx - hitboxWidth / 2,
      top: pos.dy - diameter / 2,
      width: hitboxWidth,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        onEnter: (_) => setState(() => _hoveredNodeId = node.id),
        onExit: (_) {
          if (_hoveredNodeId == node.id) {
            setState(() => _hoveredNodeId = null);
          }
        },
        child: Semantics(
          button: true,
          label: node.label,
          onTap: openQuickView,
          excludeSemantics: true,
          child: FocusableActionDetector(
            focusNode: _focusNodeFor(node),
            shortcuts: const <ShortcutActivator, Intent>{
              SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
              SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            },
            actions: <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  openQuickView();
                  return null;
                },
              ),
            },
            onShowFocusHighlight: (focused) {
              setState(() {
                if (focused) {
                  _focusedNodeId = node.id;
                } else if (_focusedNodeId == node.id) {
                  _focusedNodeId = null;
                }
              });
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: openQuickView,
              onPanUpdate: (details) {
                setState(() {
                  _draggedNodeIds.add(node.id);
                  final updated = pos + details.delta / _scale;
                  _positions[node.id] = Offset(
                    updated.dx.clamp(
                      30.0,
                      math.max(30.0, canvasSize.width - 30.0),
                    ),
                    updated.dy.clamp(
                      30.0,
                      math.max(30.0, canvasSize.height - 30.0),
                    ),
                  );
                });
              },
              child: AnimatedOpacity(
                duration: _reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                opacity:
                    t * (isGalaxy && !isContextNode && !isMatch ? 0.24 : 1),
                child: Transform.scale(
                  scale:
                      (0.4 + 0.6 * t) *
                      pulse *
                      (isGalaxy && (isHovered || isFocused) ? 1.14 : 1),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: blinkOpacity,
                        child: Container(
                          decoration: isFocused && !isGalaxy
                              ? BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: focusColor,
                                    width: 3,
                                  ),
                                )
                              : null,
                          child: isGalaxy
                              ? _buildStarDot(
                                  node,
                                  color,
                                  isRoot,
                                  isMatch,
                                  diameter,
                                  isFocused: isFocused,
                                  isHovered: isHovered,
                                )
                              : _buildIconNode(
                                  node,
                                  color,
                                  isRoot,
                                  isMatch,
                                  diameter,
                                ),
                        ),
                      ),
                      if (showLabel) ...[
                        const SizedBox(height: 4),
                        DecoratedBox(
                          decoration: isGalaxy
                              ? BoxDecoration(
                                  color: FncColors.galaxyLabel,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.32),
                                  ),
                                )
                              : const BoxDecoration(),
                          child: Padding(
                            padding: isGalaxy
                                ? const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  )
                                : EdgeInsets.zero,
                            child: Text(
                              node.label,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: FncFonts.size11,
                                fontWeight: isRoot
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isGalaxy ? FncColors.white : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Diámetro real del nodo, según el modo y si es la raíz: única fuente
  /// de verdad tanto para dibujar el círculo/punto como para calcular su
  /// posición (ver `_buildNode`), así ambos quedan siempre coordinados.
  double _nodeDiameter(
    GraphNode node, {
    required bool isRoot,
    required bool isGalaxy,
    required int degree,
  }) {
    if (isGalaxy) {
      return isRoot ? 46.0 : 12.0 + math.min(6.0, degree * 1.4);
    }
    return isRoot ? 72.0 : 54.0;
  }

  /// Nodo con icono dentro de un círculo de color, usado en los modos
  /// jerárquicos (comportamiento sin cambios respecto al diseño original).
  Widget _buildIconNode(
    GraphNode node,
    Color color,
    bool isRoot,
    bool isMatch,
    double diameter,
  ) {
    return Container(
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
              color: FncColors.materialAmber.withValues(alpha: 0.7),
              blurRadius: 20,
              spreadRadius: 3,
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        iconForType(node.type),
        color: FncColors.white,
        size: isRoot ? 30 : 22,
      ),
    );
  }

  /// Nodo "estrella" del modo galaxia: un punto pequeño con brillo, sin
  /// icono, para que cientos de nodos quepan sin saturarse visualmente. El
  /// tamaño de los nodos no-raíz varía levemente (según el hash del id)
  /// para dar textura de cielo estrellado en vez de puntos uniformes.
  Widget _buildStarDot(
    GraphNode node,
    Color color,
    bool isRoot,
    bool isMatch,
    double diameter, {
    required bool isFocused,
    required bool isHovered,
  }) {
    final emphasized = isFocused || isHovered || isMatch;
    return AnimatedContainer(
      duration: _reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: isRoot
              ? [FncColors.white, color, color.withValues(alpha: 0.55)]
              : [FncColors.white, color],
          stops: isRoot ? const [0, 0.38, 1] : const [0.1, 1],
        ),
        border: Border.all(
          color: emphasized
              ? FncColors.white.withValues(alpha: 0.92)
              : color.withValues(alpha: isRoot ? 0.9 : 0.55),
          width: isRoot ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: emphasized ? 0.82 : 0.48),
            blurRadius: diameter * (emphasized ? 2.1 : 1.35),
            spreadRadius: emphasized ? diameter * 0.22 : 0,
          ),
          if (isRoot)
            BoxShadow(
              color: FncColors.blue.withValues(alpha: 0.25),
              blurRadius: 34,
              spreadRadius: 10,
            ),
          if (isMatch)
            BoxShadow(
              color: FncColors.materialAmber.withValues(alpha: 0.8),
              blurRadius: 24,
              spreadRadius: 4,
            ),
        ],
      ),
      alignment: Alignment.center,
      child: isRoot
          ? Icon(iconForType(node.type), color: FncColors.white, size: 20)
          : null,
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
                color: FncColors.white,
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
