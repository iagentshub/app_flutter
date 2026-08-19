import 'package:app_flutter/shared/graph/graph_edge_painter.dart';
import 'package:app_flutter/shared/graph/graph_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// `shouldRepaint` compara las posiciones una a una, y no por identidad del
/// mapa, porque el `build` lo recrea en cada `setState`. El riesgo del
/// cambio está en el otro lado: afinarlo de más deja la arista clavada
/// donde estaba mientras el nodo ya se ha movido.
void main() {
  const edges = [GraphEdge(sourceId: 'a', targetId: 'b')];

  GraphEdgePainter pintor(
    Map<String, Offset> positions, {
    String? highlighted,
    double progress = 1,
  }) => GraphEdgePainter(
    edges: edges,
    positions: positions,
    progress: progress,
    cache: GraphEdgePathCache(),
    highlightedNodeId: highlighted,
  );

  test('mover un nodo repinta; repetir el mismo estado, no', () {
    final antes = pintor({'a': Offset.zero, 'b': const Offset(10, 10)});

    // Otro mapa con el mismo contenido: el `build` lo recrea sin que haya
    // cambiado nada.
    final mismo = pintor({'a': Offset.zero, 'b': const Offset(10, 10)});
    expect(mismo.shouldRepaint(antes), isFalse);

    final movido = pintor({'a': Offset.zero, 'b': const Offset(40, 10)});
    expect(movido.shouldRepaint(antes), isTrue);
  });

  test('el nodo bajo el puntero y el progreso de entrada repintan', () {
    const posiciones = {'a': Offset.zero, 'b': Offset(10, 10)};
    final antes = pintor(posiciones);

    expect(pintor(posiciones, highlighted: 'a').shouldRepaint(antes), isTrue);
    expect(pintor(posiciones, progress: 0.5).shouldRepaint(antes), isTrue);
  });

  test('un nodo que desaparece repinta aunque los demás no se muevan', () {
    final antes = pintor({'a': Offset.zero, 'b': const Offset(10, 10)});
    final sinB = pintor({'a': Offset.zero});
    expect(sinB.shouldRepaint(antes), isTrue);
  });
}
