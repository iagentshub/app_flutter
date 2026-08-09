import 'package:app_flutter/shared/graph/animated_resource_graph.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:app_flutter/shared/graph/graph_sort_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  testWidgets(
    'cambiar el modo de orden desde el controlador no lanza excepciones',
    (tester) async {
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
    },
  );

  /// Las dos animaciones cíclicas del grafo no paraban nunca mientras el
  /// widget estuviera montado: con el diálogo abierto la app no llegaba a un
  /// frame en reposo, lo que en web mantiene vivo el requestAnimationFrame y
  /// en portátil o móvil se nota en la batería.
  testWidgets('las animaciones cíclicas se paran cuando no hacen falta', (
    tester,
  ) async {
    const nodes = [
      GraphNode(id: 'root', label: 'Agente raíz', type: 'agent'),
      GraphNode(id: 'skill:a', label: 'Skill A', type: 'skill'),
    ];
    const edges = [GraphEdge(sourceId: 'root', targetId: 'skill:a')];

    Widget grafo(String query) => wrap(
      AnimatedResourceGraph(
        nodes: nodes,
        edges: edges,
        rootId: 'root',
        highlightQuery: query,
        quickViewDescriptionLabel: 'Descripción',
        quickViewNoDescriptionLabel: 'Sin descripción',
        quickViewConnectionsLabel: 'Conexiones',
        quickViewNoConnectionsLabel: 'Sin conexiones',
        quickViewCloseTooltip: 'Cerrar',
      ),
    );

    // El State es privado, así que los diagnósticos se leen sin tipar.
    dynamic estado() => tester.state(find.byType(AnimatedResourceGraph));

    await tester.pumpWidget(grafo(''));
    await tester.pump(const Duration(milliseconds: 1200));

    // Sin búsqueda no hay nada que parpadear; el pulso de la raíz sí corre.
    expect(estado().debugBlinkAnimating, isFalse);
    expect(estado().debugPulseAnimating, isTrue);

    // Al buscar, el parpadeo arranca.
    await tester.pumpWidget(grafo('Skill'));
    await tester.pump();
    expect(estado().debugBlinkAnimating, isTrue);

    // Y al borrar la búsqueda se detiene otra vez.
    await tester.pumpWidget(grafo(''));
    await tester.pump();
    expect(estado().debugBlinkAnimating, isFalse);

    // Con la app en segundo plano no queda ninguna animación viva. El
    // framework valida la secuencia, así que se recorre entera.
    for (final estadoApp in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(estadoApp);
    }
    await tester.pump();
    expect(estado().debugPulseAnimating, isFalse);
    expect(estado().debugBlinkAnimating, isFalse);

    // Y al volver al primer plano el pulso se reanuda.
    for (final estadoApp in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(estadoApp);
    }
    await tester.pump();
    expect(estado().debugPulseAnimating, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('respeta la preferencia de movimiento reducido', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    const nodes = [
      GraphNode(id: 'root', label: 'Agente raíz', type: 'agent'),
      GraphNode(id: 'skill:a', label: 'Skill A', type: 'skill'),
    ];

    await tester.pumpWidget(
      wrap(
        const AnimatedResourceGraph(
          nodes: nodes,
          edges: [GraphEdge(sourceId: 'root', targetId: 'skill:a')],
          rootId: 'root',
          highlightQuery: 'Skill',
          quickViewDescriptionLabel: 'Descripción',
          quickViewNoDescriptionLabel: 'Sin descripción',
          quickViewConnectionsLabel: 'Conexiones',
          quickViewNoConnectionsLabel: 'Sin conexiones',
          quickViewCloseTooltip: 'Cerrar',
        ),
      ),
    );
    await tester.pump();

    final dynamic state = tester.state(find.byType(AnimatedResourceGraph));
    expect(state.debugEntranceCompleted, isTrue);
    expect(state.debugPulseAnimating, isFalse);
    expect(state.debugBlinkAnimating, isFalse);
  });

  testWidgets('el layout Galaxia grande se reparte entre varios frames', (
    tester,
  ) async {
    final nodes = [
      const GraphNode(id: 'root', label: 'Raíz', type: 'agent'),
      for (var i = 0; i < 64; i++)
        GraphNode(id: 'node-$i', label: 'Nodo $i', type: 'skill'),
    ];
    final edges = [
      for (var i = 0; i < 64; i++)
        GraphEdge(sourceId: 'root', targetId: 'node-$i'),
    ];
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
    controller.setMode(GraphSortMode.galaxy);
    await tester.pump();

    dynamic state = tester.state(find.byType(AnimatedResourceGraph));
    expect(state.debugGalaxyLayoutPending, isTrue);

    for (
      var frame = 0;
      frame < 80 && state.debugGalaxyLayoutPending == true;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 16));
      state = tester.state(find.byType(AnimatedResourceGraph));
    }
    expect(state.debugGalaxyLayoutPending, isFalse);
    expect(tester.takeException(), isNull);
  });
}
