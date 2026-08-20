import 'dart:math' as math;

import 'package:app_flutter/shared/graph/animated_resource_graph.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:app_flutter/shared/graph/graph_sort_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cómo queda repartida la galaxia, medido sobre un móvil.
///
/// El reparto anterior era una simulación de fuerzas y en una pantalla
/// estrecha terminaba con 109 de 121 nodos aplastados contra el borde del
/// lienzo: la suma de repulsiones crece con el número de nodos y acaba
/// venciendo a cualquier gravedad, y el recorte rectangular los alineaba
/// contra los lados. Estas medidas son la red que impide volver ahí.
void main() {
  /// Grafo realista: un agente con 8 ramas y 14 dependencias en cada una.
  ({List<GraphNode> nodes, List<GraphEdge> edges}) grafoDePrueba() {
    final nodes = <GraphNode>[
      const GraphNode(id: 'root', label: 'Agente', type: 'agent'),
    ];
    final edges = <GraphEdge>[];
    for (var r = 0; r < 8; r++) {
      nodes.add(GraphNode(id: 'r$r', label: 'Rama $r', type: 'skill'));
      edges.add(GraphEdge(sourceId: 'root', targetId: 'r$r'));
      for (var h = 0; h < 14; h++) {
        nodes.add(GraphNode(id: 'r$r-h$h', label: 'H$h', type: 'knowledge'));
        edges.add(GraphEdge(sourceId: 'r$r', targetId: 'r$r-h$h'));
      }
    }
    return (nodes: nodes, edges: edges);
  }

  Future<dynamic> montar(WidgetTester tester) async {
    // Móvil de 360x700 lógicos: el caso donde el reparto anterior se rompía.
    tester.view.physicalSize = const Size(1080, 2100);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final grafo = grafoDePrueba();
    final controller = GraphSortController(GraphSortMode.galaxy);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: AnimatedResourceGraph(
              nodes: grafo.nodes,
              edges: grafo.edges,
              rootId: 'root',
              sortController: controller,
              showLabels: false,
              quickViewDescriptionLabel: 'D',
              quickViewNoDescriptionLabel: 'S',
              quickViewConnectionsLabel: 'C',
              quickViewNoConnectionsLabel: 'S',
              quickViewCloseTooltip: 'X',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tester.state(find.byType(AnimatedResourceGraph));
  }

  List<Offset> posicionesDe(dynamic state) {
    final grafo = <Offset>[];
    for (var r = 0; r < 8; r++) {
      grafo.add(state.debugPositionFor('r$r') as Offset);
      for (var h = 0; h < 14; h++) {
        grafo.add(state.debugPositionFor('r$r-h$h') as Offset);
      }
    }
    grafo.add(state.debugPositionFor('root') as Offset);
    return grafo;
  }

  testWidgets('ningún nodo acaba contra el borde del lienzo', (tester) async {
    final state = await montar(tester);
    final canvas = state.debugCanvasSize as Size;
    final centro = Offset(canvas.width / 2, canvas.height / 2);
    final radioDisco = math.min(canvas.width, canvas.height) * 0.42;

    final pegados = posicionesDe(
      state,
    ).where((p) => (p - centro).distance > radioDisco - 1).length;

    expect(
      pegados,
      0,
      reason:
          'la galaxia vive dentro de un disco centrado; un nodo en su borde '
          'significa que algo lo está empujando hacia fuera',
    );
  });

  testWidgets('el lienzo es cuadrado, no con la forma de la pantalla', (
    tester,
  ) async {
    final state = await montar(tester);
    final canvas = state.debugCanvasSize as Size;

    expect(
      canvas.width / canvas.height,
      closeTo(1, 0.01),
      reason:
          'heredar el aspecto del visor estiraba la galaxia hasta volverla un '
          'pasillo en pantallas estrechas',
    );
  });

  testWidgets('los nodos no se amontonan unos sobre otros', (tester) async {
    final state = await montar(tester);
    final posiciones = posicionesDe(state);

    var minima = double.infinity;
    for (var i = 0; i < posiciones.length; i++) {
      for (var j = i + 1; j < posiciones.length; j++) {
        final d = (posiciones[i] - posiciones[j]).distance;
        if (d < minima) minima = d;
      }
    }

    expect(
      minima,
      greaterThan(28),
      reason:
          'el lienzo se dimensiona por el anillo más poblado justamente para '
          'que quepan sin tocarse',
    );
  });

  testWidgets('hay núcleo: la densidad decrece hacia fuera', (tester) async {
    final state = await montar(tester);
    final canvas = state.debugCanvasSize as Size;
    final centro = Offset(canvas.width / 2, canvas.height / 2);
    final radioDisco = math.min(canvas.width, canvas.height) * 0.42;
    final radios = posicionesDe(
      state,
    ).map((p) => (p - centro).distance).toList();

    // Un layout de fuerzas repartía por área y dejaba el tercio exterior
    // como el más poblado: un anillo, no una galaxia.
    final interior = radios.where((r) => r < radioDisco / 3).length;
    final exterior = radios.where((r) => r > radioDisco * 2 / 3).length;

    expect(
      exterior,
      lessThan(interior),
      reason: 'el borde no puede ser la zona con más nodos',
    );
  });
}
