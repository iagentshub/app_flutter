import 'package:app_flutter/shared/graph/animated_resource_graph.dart';
import 'package:app_flutter/shared/graph/graph_dialog.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El buscador aplicaba la consulta en cada pulsación, y cada una reconstruye
/// el grafo entero: comparación con el grafo anterior y `_matches` nodo a
/// nodo. Escribir una palabra de siete letras costaba siete rondas.
void main() {
  const nodes = [
    GraphNode(id: 'root', label: 'Agente', type: 'agent'),
    GraphNode(id: 'skill:a', label: 'memoria larga', type: 'skill'),
    GraphNode(id: 'skill:b', label: 'otra cosa', type: 'skill'),
  ];
  const edges = [
    GraphEdge(sourceId: 'root', targetId: 'skill:a'),
    GraphEdge(sourceId: 'root', targetId: 'skill:b'),
  ];

  /// El parpadeo solo corre cuando hay una consulta que resaltar, así que
  /// delata si la búsqueda ya se aplicó.
  bool buscando(WidgetTester tester) {
    final estado = tester.state(find.byType(AnimatedResourceGraph)) as dynamic;
    return estado.debugBlinkAnimating as bool;
  }

  Future<void> abrirDialogo(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showResourceGraphDialog(
                context: context,
                title: 'Grafo',
                nodes: nodes,
                edges: edges,
                rootId: 'root',
                closeLabel: 'Cerrar',
                searchHint: 'Buscar...',
                sortTooltip: 'Ordenar',
                sortHierarchyVerticalLabel: 'Vertical',
                sortHierarchyHorizontalLabel: 'Horizontal',
                sortGalaxyLabel: 'Galaxia',
                showLabelsTooltip: 'Mostrar',
                hideLabelsTooltip: 'Ocultar',
                quickViewDescriptionLabel: 'Descripción',
                quickViewNoDescriptionLabel: 'Sin descripción',
                quickViewConnectionsLabel: 'Conexiones',
                quickViewNoConnectionsLabel: 'Sin conexiones',
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
  }

  testWidgets('teclear no aplica la búsqueda hasta que el usuario para', (
    tester,
  ) async {
    await abrirDialogo(tester);
    expect(buscando(tester), isFalse);

    await tester.enterText(find.byType(TextField), 'memo');
    await tester.pump();
    expect(
      buscando(tester),
      isFalse,
      reason: 'la pulsación no debe llegar todavía al grafo',
    );

    await tester.pump(const Duration(milliseconds: 250));
    expect(buscando(tester), isTrue);

    // Y limpiar el campo se aplica ya: esperar a ver el grafo entero de
    // vuelta se siente como un tirón.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(buscando(tester), isFalse);

    expect(tester.takeException(), isNull);
  });
}
