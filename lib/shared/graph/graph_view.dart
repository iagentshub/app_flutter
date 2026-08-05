import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    case 'prompt':
      return Icons.bolt_outlined;
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
/// (raíz arriba/izquierda y capas hacia abajo/derecha) y "galaxia", un
/// layout de fuerzas (repulsión/atracción) pensado para grafos grandes.
enum GraphSortMode { hierarchyVertical, hierarchyHorizontal, galaxy }

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
  // Semilla fija: reabrir el mismo recurso reproduce el mismo layout.
  static const _galaxySeed = 20260804;

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
  final Map<String, FocusNode> _nodeFocusNodes = {};
  String? _focusedNodeId;

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
    for (final focusNode in _nodeFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedResourceGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentIds = widget.nodes.map((node) => node.id).toSet();
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
      return Size(
        math.max(viewport.width * _galaxyMinCanvasFactor, width),
        math.max(viewport.height * _galaxyMinCanvasFactor, height),
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
    if (_sortMode == GraphSortMode.galaxy) {
      _ensureGalaxyPositions(canvasSize);
    } else {
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

  /// Layout de fuerzas (tipo Fruchterman-Reingold): cada nodo se repele de
  /// todos los demás y se atrae a lo largo de sus aristas, con una leve
  /// gravedad hacia el centro para no dispersarse sin límite. A diferencia
  /// de los layouts jerárquicos, los clusters emergen del propio grafo en
  /// vez de imponerse por niveles, lo que evita el amontonamiento típico
  /// de grafos grandes (cientos de nodos) en una disposición fija.
  ///
  /// Se ejecuta con arrays indexados (no `Map<String,Offset>`) porque el
  /// bucle de repulsión es O(n²) por iteración: con cientos de nodos el
  /// coste de hashing/autoboxing de `Offset` sí se nota.
  void _ensureGalaxyPositions(Size canvasSize) {
    final n = widget.nodes.length;
    if (n == 0) return;

    final ids = [for (final node in widget.nodes) node.id];
    final rootIndex = ids.indexOf(widget.rootId);
    final center = Offset(canvasSize.width / 2, canvasSize.height / 2);
    final random = math.Random(_galaxySeed);

    final px = List<double>.filled(n, 0);
    final py = List<double>.filled(n, 0);
    final pinned = List<bool>.filled(n, false);
    final seedRadius = math.min(canvasSize.width, canvasSize.height) * 0.35;
    for (var i = 0; i < n; i++) {
      final existing = _positions[ids[i]];
      if (existing != null) {
        px[i] = existing.dx;
        py[i] = existing.dy;
        pinned[i] = true;
        continue;
      }
      if (i == rootIndex) {
        px[i] = center.dx;
        py[i] = center.dy;
        pinned[i] = true;
        continue;
      }
      final angle = random.nextDouble() * 2 * math.pi;
      final radius = seedRadius * math.sqrt(random.nextDouble());
      px[i] = center.dx + radius * math.cos(angle);
      py[i] = center.dy + radius * math.sin(angle);
    }

    final idIndex = {for (var i = 0; i < n; i++) ids[i]: i};
    final edgesIdx = [
      for (final edge in widget.edges)
        if (idIndex.containsKey(edge.sourceId) &&
            idIndex.containsKey(edge.targetId))
          (idIndex[edge.sourceId]!, idIndex[edge.targetId]!),
    ];

    final area = canvasSize.width * canvasSize.height;
    final k = _galaxyIdealLengthFactor * math.sqrt(area / n);
    final iterations = _galaxyIterationsFor(n);
    final t0 = math.max(canvasSize.width, canvasSize.height) * 0.05;
    final dispX = List<double>.filled(n, 0);
    final dispY = List<double>.filled(n, 0);

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

      // Gravedad uniforme hacia el centro.
      for (var i = 0; i < n; i++) {
        dispX[i] += (center.dx - px[i]) * _galaxyGravity;
        dispY[i] += (center.dy - py[i]) * _galaxyGravity;
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
    }

    for (var i = 0; i < n; i++) {
      _positions[ids[i]] = Offset(px[i], py[i]);
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
    return Offset(
      offset.dx.clamp(minDx, maxDx),
      offset.dy.clamp(minDy, maxDy),
    );
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
    // Fondo del modo galaxia: el mismo negro del tema oscuro de la app
    // (no un color propio), cubriendo todo el visor y no solo el lienzo
    // (que puede ser más pequeño tras un zoom-out).
    final galaxyBackground = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      color: _sortMode == GraphSortMode.galaxy ? galaxyBackground : null,
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
        final scaledWidth = canvasSize.width * _scale;
        final scaledHeight = canvasSize.height * _scale;
        return Listener(
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final canvasPointUnderCursor =
                (event.localPosition - _panOffset) / _scale;
            final newScale = (_scale * math.exp(-event.scrollDelta.dy * 0.0015))
                .clamp(_minScaleFor(viewport, canvasSize), _maxScale);
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
                                    lineColor: _sortMode == GraphSortMode.galaxy
                                        ? Colors.white.withValues(alpha: 0.22)
                                        : Colors.grey,
                                    dashedColor:
                                        _sortMode == GraphSortMode.galaxy
                                        ? Colors.orangeAccent.withValues(
                                            alpha: 0.35,
                                          )
                                        : Colors.orange,
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
      ),
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
    final isMatch = _matches(node);
    final isFocused = _focusedNodeId == node.id;
    final blinkOpacity = isMatch ? (0.35 + 0.65 * _blink.value) : 1.0;
    final focusColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;

    void openQuickView() => _showQuickView(context, node);

    final isGalaxy = _sortMode == GraphSortMode.galaxy;
    final showLabel = widget.showLabels || isMatch;
    // El círculo/punto es el primer hijo del Column de abajo, así que su
    // centro debe coincidir exactamente con `pos` (donde termina la
    // arista dibujada por `_GraphEdgePainter`): un offset fijo pensado
    // para el nodo grande del modo jerárquico (72/54px) deja la línea
    // notoriamente corta contra los puntos pequeños de la galaxia
    // (8-26px), así que se calcula según el diámetro real de cada nodo.
    final diameter = _nodeDiameter(node, isRoot: isRoot, isGalaxy: isGalaxy);
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
                          decoration: isFocused
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
                        Text(
                          node.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isRoot
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isGalaxy ? Colors.white : null,
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
  double _nodeDiameter(GraphNode node, {required bool isRoot, required bool isGalaxy}) {
    if (isGalaxy) {
      return isRoot ? 26.0 : 8.0 + (node.id.hashCode.abs() % 5);
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
    double diameter,
  ) {
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Colors.white, color],
          stops: const [0.15, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: diameter * 1.6,
            spreadRadius: diameter * 0.15,
          ),
          if (isMatch)
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.7),
              blurRadius: 20,
              spreadRadius: 3,
            ),
        ],
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
    this.lineColor = Colors.grey,
    this.dashedColor = Colors.orange,
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
  bool shouldRepaint(covariant _GraphEdgePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.nodes != nodes ||
      oldDelegate.edges != edges ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.dashedColor != dashedColor;
}
