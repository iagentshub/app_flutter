import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_flutter/shared/graph/graph_dialog.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:app_flutter/shared/graph/graph_view.dart';

void main() {
  testWidgets('opens graph dialog, drags a node and pans background without exceptions', (
    tester,
  ) async {
    // Tamaño de un iPhone real (mismo escenario reportado como roto), para
    // forzar un lienzo mayor que el visor y así poder probar el pan.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final nodes = [
      const GraphNode(id: 'root', label: 'Workflow', type: 'workflow'),
      const GraphNode(id: 'step1', label: 'Agent 1', type: 'agent'),
      const GraphNode(id: 'step2', label: 'Agent 2', type: 'agent'),
      const GraphNode(id: 'step3', label: 'Agent 3', type: 'agent'),
      const GraphNode(id: 'skill:shared', label: 'shared skill', type: 'skill'),
      const GraphNode(id: 'skill:a', label: 'skill a', type: 'skill'),
      const GraphNode(id: 'skill:b', label: 'skill b', type: 'skill'),
      const GraphNode(
        id: 'knowledge:a',
        label: 'knowledge a',
        type: 'knowledge',
      ),
      const GraphNode(id: 'connection:x', label: 'conn x', type: 'connection'),
    ];
    final edges = [
      const GraphEdge(sourceId: 'root', targetId: 'step1'),
      const GraphEdge(sourceId: 'root', targetId: 'step2'),
      const GraphEdge(sourceId: 'root', targetId: 'step3'),
      const GraphEdge(sourceId: 'step1', targetId: 'skill:shared'),
      const GraphEdge(sourceId: 'step2', targetId: 'skill:shared'),
      const GraphEdge(sourceId: 'step1', targetId: 'skill:a'),
      const GraphEdge(sourceId: 'step2', targetId: 'skill:b'),
      const GraphEdge(sourceId: 'step3', targetId: 'knowledge:a'),
      const GraphEdge(sourceId: 'step3', targetId: 'connection:x'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showResourceGraphDialog(
                context: context,
                title: 'Test workflow',
                nodes: nodes,
                edges: edges,
                rootId: 'root',
                closeLabel: 'Cerrar',
                searchHint: 'Buscar...',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    // Animaciones de pulso/parpadeo se repiten indefinidamente, así que no
    // se puede usar pumpAndSettle: avanzamos un tiempo fijo en su lugar.
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(tester.takeException(), isNull);
    expect(find.text('Test workflow'), findsOneWidget);

    // Arrastrar un nodo debe mover su posición.
    final nodeFinder = find.text('Agent 1');
    expect(nodeFinder, findsOneWidget);
    final beforeNodeDrag = tester.getTopLeft(nodeFinder);
    await tester.drag(nodeFinder, const Offset(30, 20));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final afterNodeDrag = tester.getTopLeft(nodeFinder);
    expect(
      afterNodeDrag,
      isNot(equals(beforeNodeDrag)),
      reason: 'Arrastrar un nodo debería reposicionarlo',
    );

    // Arrastrar el fondo (pan) debe mover TODOS los nodos por igual: se
    // toca una esquina del área del grafo (lejos de cualquier nodo, que
    // está centrado), no una coordenada global arbitraria que caería sobre
    // el título o el buscador.
    final graphRect = tester.getRect(find.byType(AnimatedResourceGraph));
    final backgroundPoint = graphRect.topLeft + const Offset(10, 10);
    final rootFinder = find.text('Workflow');
    final beforePan = tester.getTopLeft(rootFinder);
    await tester.dragFrom(backgroundPoint, const Offset(-60, -40));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final afterPan = tester.getTopLeft(rootFinder);
    expect(
      afterPan,
      isNot(equals(beforePan)),
      reason: 'Arrastrar el fondo debería desplazar el lienzo (pan)',
    );

    // Hacer zoom con la rueda del ratón sobre el lienzo debe escalar la
    // separación entre nodos, sin lanzar excepciones.
    final agent2Finder = find.text('Agent 2');
    final beforeZoomStep1 = tester.getTopLeft(find.text('Agent 1'));
    final beforeZoomStep2 = tester.getTopLeft(agent2Finder);
    final beforeZoomDistance = (beforeZoomStep2 - beforeZoomStep1).distance;
    final zoomFocalPoint = tester.getCenter(
      find.byType(AnimatedResourceGraph),
    );
    final testPointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      testPointer.hover(zoomFocalPoint),
    );
    await tester.sendEventToBinding(
      testPointer.scroll(const Offset(0, -600)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    final afterZoomStep1 = tester.getTopLeft(find.text('Agent 1'));
    final afterZoomStep2 = tester.getTopLeft(agent2Finder);
    final afterZoomDistance = (afterZoomStep2 - afterZoomStep1).distance;
    expect(
      afterZoomDistance,
      greaterThan(beforeZoomDistance),
      reason: 'La rueda del ratón debería acercar (zoom in) el grafo',
    );

    // Buscar resalta sin romper nada.
    await tester.enterText(find.byType(TextField), 'shared');
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
}
