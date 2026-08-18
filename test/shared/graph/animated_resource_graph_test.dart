import 'package:app_flutter/shared/graph/animated_resource_graph.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:app_flutter/shared/graph/graph_sort_controller.dart';
import 'package:flutter/gestures.dart';
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

  testWidgets('el layout Galaxia grande sale en el mismo frame', (
    tester,
  ) async {
    // Fue una simulación de fuerzas troceada entre frames. Ahora el reparto
    // es geométrico —anillo por profundidad, sector por rama— y se resuelve
    // en un recorrido del árbol, así que no hay nada que esperar.
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

    final dynamic state = tester.state(find.byType(AnimatedResourceGraph));
    for (var i = 0; i < 64; i++) {
      expect(state.debugPositionFor('node-$i'), isNotNull);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Galaxia agrupa por dependencia, no por tipo', (tester) async {
    // Dos agentes con una skill cada uno. Lo que tiene que quedar junto es
    // cada agente con SU skill; hubo un agrupamiento por familia de tipo que
    // llevaba las dos skills al mismo sitio y separaba a cada agente de
    // aquello que usa.
    const nodes = [
      GraphNode(id: 'root', label: 'Orquestación', type: 'workflow'),
      GraphNode(id: 'agente-a', label: 'Agente A', type: 'agent'),
      GraphNode(id: 'agente-b', label: 'Agente B', type: 'agent'),
      GraphNode(id: 'skill-a', label: 'Skill A', type: 'skill'),
      GraphNode(id: 'skill-b', label: 'Skill B', type: 'skill'),
    ];
    const edges = [
      GraphEdge(sourceId: 'root', targetId: 'agente-a'),
      GraphEdge(sourceId: 'root', targetId: 'agente-b'),
      GraphEdge(sourceId: 'agente-a', targetId: 'skill-a'),
      GraphEdge(sourceId: 'agente-b', targetId: 'skill-b'),
    ];
    final controller = GraphSortController(GraphSortMode.galaxy);
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
    await tester.pump();

    final dynamic state = tester.state(find.byType(AnimatedResourceGraph));
    Offset posicion(String id) => state.debugPositionFor(id) as Offset;
    final aSuDependencia = (posicion('agente-a') - posicion('skill-a')).distance;
    final alMismoTipo = (posicion('skill-a') - posicion('skill-b')).distance;

    expect(
      aSuDependencia,
      lessThan(alMismoTipo),
      reason:
          'una skill debe quedar más cerca del agente que la usa que de otra '
          'skill con la que no tiene ninguna relación',
    );
  });

  testWidgets('un nodo lejos del centro del lienzo sigue respondiendo', (
    tester,
  ) async {
    // El lienzo de Galaxia es varias veces el visor, pero el `Positioned` que
    // lo aloja mide lo que ocupa en pantalla. Sin un `OverflowBox`, el `Stack`
    // interior heredaba ese tamaño menor y descartaba el hit test de todo lo
    // que cayera más allá: los nodos alejados se veían y no respondían ni al
    // ratón ni al clic.
    final nodes = [
      const GraphNode(id: 'root', label: 'Raíz', type: 'agent'),
      for (var i = 0; i < 24; i++)
        GraphNode(id: 'skill-$i', label: 'Skill $i', type: 'skill'),
    ];
    final edges = [
      for (var i = 0; i < 24; i++)
        GraphEdge(sourceId: 'root', targetId: 'skill-$i'),
    ];
    final controller = GraphSortController(GraphSortMode.galaxy);
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

    dynamic state = tester.state(find.byType(AnimatedResourceGraph));
    // El más alejado del centro: el que el hit test perdía.
    final centro = state.debugPositionFor('root') as Offset;
    var lejano = 'skill-0';
    var maxDistancia = 0.0;
    for (var i = 0; i < 24; i++) {
      final posicion = state.debugPositionFor('skill-$i') as Offset?;
      if (posicion == null) continue;
      final distancia = (posicion - centro).distance;
      if (distancia > maxDistancia) {
        maxDistancia = distancia;
        lejano = 'skill-$i';
      }
    }

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(
      tester.getCenter(find.text(lejano.replaceFirst('skill-', 'Skill '))),
    );
    await tester.pump();

    state = tester.state(find.byType(AnimatedResourceGraph));
    expect(state.debugHighlightedNodeId, lejano);
  });

  testWidgets('Galaxia realza el nodo bajo el puntero', (tester) async {
    const nodes = [
      GraphNode(id: 'root', label: 'Raíz', type: 'agent'),
      GraphNode(id: 'skill:a', label: 'Skill A', type: 'skill'),
    ];
    final controller = GraphSortController(GraphSortMode.galaxy);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrap(
        AnimatedResourceGraph(
          nodes: nodes,
          edges: const [GraphEdge(sourceId: 'root', targetId: 'skill:a')],
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

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('Skill A')));
    await tester.pump();

    final dynamic state = tester.state(find.byType(AnimatedResourceGraph));
    expect(state.debugHighlightedNodeId, 'skill:a');
  });

  testWidgets('un nodo arrastrado permanece fijado en Galaxia', (tester) async {
    const nodes = [
      GraphNode(id: 'root', label: 'Raíz', type: 'agent'),
      GraphNode(id: 'skill:a', label: 'Skill A', type: 'skill'),
      GraphNode(id: 'skill:b', label: 'Skill B', type: 'skill'),
    ];
    final controller = GraphSortController(GraphSortMode.galaxy);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      wrap(
        AnimatedResourceGraph(
          nodes: nodes,
          edges: const [
            GraphEdge(sourceId: 'root', targetId: 'skill:a'),
            GraphEdge(sourceId: 'root', targetId: 'skill:b'),
          ],
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

    dynamic state = tester.state(find.byType(AnimatedResourceGraph));
    final before = state.debugPositionFor('skill:a') as Offset;
    await tester.drag(find.text('Skill A'), const Offset(35, 20));
    await tester.pump();
    state = tester.state(find.byType(AnimatedResourceGraph));
    final dragged = state.debugPositionFor('skill:a') as Offset;
    expect(dragged, isNot(before));

    await tester.pump(const Duration(milliseconds: 500));
    state = tester.state(find.byType(AnimatedResourceGraph));
    expect(state.debugPositionFor('skill:a'), dragged);
  });
}
