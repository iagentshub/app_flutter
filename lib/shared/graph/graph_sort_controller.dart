import 'package:flutter/foundation.dart';

/// Formas de ordenar automáticamente el grafo: dos variantes jerárquicas
/// (raíz arriba/izquierda y capas hacia abajo/derecha) y "galaxia", un
/// layout de fuerzas (repulsión/atracción) pensado para grafos grandes.
enum GraphSortMode { hierarchyVertical, hierarchyHorizontal, galaxy }

/// Controla el modo de ordenación desde fuera de `AnimatedResourceGraph`
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
