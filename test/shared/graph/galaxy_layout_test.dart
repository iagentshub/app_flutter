import 'package:app_flutter/shared/graph/galaxy_layout.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const nodes = [
    GraphNode(id: 'root', label: 'Root', type: 'workflow'),
    GraphNode(id: 'skill-a', label: 'Skill A', type: 'skill'),
    GraphNode(id: 'skill-b', label: 'Skill B', type: 'skill'),
    GraphNode(id: 'knowledge-a', label: 'Knowledge', type: 'knowledge'),
    GraphNode(id: 'unknown-a', label: 'Unknown A', type: 'custom-a'),
    GraphNode(id: 'unknown-b', label: 'Unknown B', type: 'custom-b'),
  ];

  test('genera centros deterministas y separados para cada constelación', () {
    final first = GalaxyLayout.centersFor(
      nodes: nodes,
      rootId: 'root',
      canvasSize: const Size(1200, 800),
    );
    final second = GalaxyLayout.centersFor(
      nodes: nodes,
      rootId: 'root',
      canvasSize: const Size(1200, 800),
    );

    expect(first, second);
    expect(first.keys, containsAll(['skill', 'knowledge', 'other']));
    expect(first['skill'], isNot(first['knowledge']));
    expect(first.length, 3);
  });

  test('agrupa tipos desconocidos en la constelación de fallback', () {
    expect(GalaxyLayout.constellationKey('custom-a'), 'other');
    expect(GalaxyLayout.constellationKey('custom-b'), 'other');
    expect(GalaxyLayout.constellationKey('agent'), 'agent');
  });

  test('no crea una constelación para una raíz aislada', () {
    final centers = GalaxyLayout.centersFor(
      nodes: const [GraphNode(id: 'root', label: 'Root', type: 'agent')],
      rootId: 'root',
      canvasSize: const Size(600, 400),
    );
    expect(centers, isEmpty);
  });
}
