import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_flutter/shared/graph/animated_resource_graph.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:app_flutter/shared/graph/graph_sort_controller.dart';

/// Test básico y aislado del widget desde que se separó de `graph_view.dart`
/// (antes controlador + widget + painter en un solo archivo de ~1170
/// líneas): no pasa por `showResourceGraphDialog`, solo monta
/// [AnimatedResourceGraph] directamente con un par de nodos.
/// El recorrido más completo (diálogo, pan, zoom, teclado) sigue en
/// `test/graph_diagnostic_test.dart`.
void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: SizedBox(width: 600, height: 600, child: child)),
  );

  testWidgets('pinta la raíz y sus nodos hijos con sus etiquetas', (
    tester,
  ) async {
    const nodes = [
      GraphNode(id: 'root', label: 'Agente raíz', type: 'agent'),
      GraphNode(id: 'skill:a', label: 'Skill A', type: 'skill'),
      GraphNode(id: 'knowledge:a', label: 'Knowledge A', type: 'knowledge'),
    ];
    const edges = [
      GraphEdge(sourceId: 'root', targetId: 'skill:a'),
      GraphEdge(sourceId: 'root', targetId: 'knowledge:a'),
    ];

    await tester.pumpWidget(
      wrap(
        const AnimatedResourceGraph(
          nodes: nodes,
          edges: edges,
          rootId: 'root',
          quickViewDescriptionLabel: 'Descripción',
          quickViewNoDescriptionLabel: 'Sin descripción',
          quickViewConnectionsLabel: 'Conexiones',
          quickViewNoConnectionsLabel: 'Sin conexiones',
          quickViewCloseTooltip: 'Cerrar',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    expect(find.text('Agente raíz'), findsOneWidget);
    expect(find.text('Skill A'), findsOneWidget);
    expect(find.text('Knowledge A'), findsOneWidget);
  });

  testWidgets('muestra el texto vacío cuando solo hay un nodo (la raíz)', (
    tester,
  ) async {
    const nodes = [GraphNode(id: 'root', label: 'Solo', type: 'agent')];

    await tester.pumpWidget(
      wrap(
        const AnimatedResourceGraph(
          nodes: nodes,
          edges: [],
          rootId: 'root',
          emptyLabel: 'Sin contenido',
          quickViewDescriptionLabel: 'Descripción',
          quickViewNoDescriptionLabel: 'Sin descripción',
          quickViewConnectionsLabel: 'Conexiones',
          quickViewNoConnectionsLabel: 'Sin conexiones',
          quickViewCloseTooltip: 'Cerrar',
        ),
      ),
    );

    expect(find.text('Sin contenido'), findsOneWidget);
    expect(find.text('Solo'), findsNothing);
  });

  testWidgets('cambiar el modo de orden desde el controlador no lanza excepciones', (
    tester,
  ) async {
    const nodes = [
      GraphNode(id: 'root', label: 'Root', type: 'agent'),
      GraphNode(id: 'a', label: 'A', type: 'skill'),
    ];
    const edges = [GraphEdge(sourceId: 'root', targetId: 'a')];
    final controller = GraphSortController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      wrap(
        AnimatedResourceGraph(
          nodes: nodes,
          edges: edges,
          rootId: 'root',
          sortController: controller,
          quickViewDescriptionLabel: 'Descripción',
          quickViewNoDescriptionLabel: 'Sin descripción',
          quickViewConnectionsLabel: 'Conexiones',
          quickViewNoConnectionsLabel: 'Sin conexiones',
          quickViewCloseTooltip: 'Cerrar',
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1200));

    controller.setMode(GraphSortMode.galaxy);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
  });
}
