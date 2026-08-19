import 'package:app_flutter/shared/graph/animated_resource_graph.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:app_flutter/shared/graph/graph_sort_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Saber si el grafo ha cambiado se resolvía serializándolo entero a una
/// cadena con todos los ids —decenas de KB con 500 nodos, tres veces por
/// actualización— para comparar dos cadenas. Ahora se recorren en paralelo,
/// y el riesgo del cambio es el contrario al de entonces: que la comparación
/// se quede corta y dé por igual un grafo que no lo es. Ahí el reparto no se
/// rehace y el usuario ve el dibujo viejo sobre datos nuevos.
void main() {
  const nodes = [
    GraphNode(id: 'root', label: 'Raíz', type: 'agent'),
    GraphNode(id: 'a', label: 'A', type: 'skill'),
    GraphNode(id: 'b', label: 'B', type: 'skill'),
    GraphNode(id: 'c', label: 'C', type: 'skill'),
  ];

  Future<dynamic> montar(
    WidgetTester tester,
    GraphSortController controller,
    List<GraphNode> nodes,
    List<GraphEdge> edges, {
    String rootId = 'root',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: AnimatedResourceGraph(
              nodes: nodes,
              edges: edges,
              rootId: rootId,
              sortController: controller,
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

  testWidgets('mismo contenido en listas nuevas: el reparto se conserva', (
    tester,
  ) async {
    final controller = GraphSortController(GraphSortMode.galaxy);
    addTearDown(controller.dispose);

    List<GraphEdge> aristas() => [
      const GraphEdge(sourceId: 'root', targetId: 'a'),
      const GraphEdge(sourceId: 'root', targetId: 'b'),
      const GraphEdge(sourceId: 'root', targetId: 'c'),
    ];

    var estado = await montar(tester, controller, [...nodes], aristas());
    final antes = estado.debugPositionFor('c') as Offset;

    // Listas distintas, mismo grafo: es lo que ocurre en cada reconstrucción
    // de la pantalla que aloja el diálogo.
    estado = await montar(tester, controller, [...nodes], aristas());
    expect(estado.debugPositionFor('c'), antes);
  });

  testWidgets('cambiar solo las aristas sí se nota', (tester) async {
    final controller = GraphSortController(GraphSortMode.galaxy);
    addTearDown(controller.dispose);

    // Mismos nodos y el mismo número de aristas: si la comparación mirara
    // solo los tamaños, este cambio pasaría desapercibido.
    var estado = await montar(tester, controller, nodes, const [
      GraphEdge(sourceId: 'root', targetId: 'a'),
      GraphEdge(sourceId: 'root', targetId: 'b'),
      GraphEdge(sourceId: 'root', targetId: 'c'),
    ]);
    final enAbanico = estado.debugPositionFor('c') as Offset;

    estado = await montar(tester, controller, nodes, const [
      GraphEdge(sourceId: 'root', targetId: 'a'),
      GraphEdge(sourceId: 'a', targetId: 'b'),
      GraphEdge(sourceId: 'b', targetId: 'c'),
    ]);
    // En cadena, 'c' cuelga a tres saltos de la raíz: otro anillo.
    expect(estado.debugPositionFor('c'), isNot(enAbanico));
  });
}
