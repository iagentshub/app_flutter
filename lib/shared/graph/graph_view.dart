/// Barrel de compatibilidad: el grafo animado vivía entero en este archivo
/// (controlador + widget + painter, ~1170 líneas). Se dividió en tres —
/// `graph_sort_controller.dart`, `animated_resource_graph.dart` y
/// `graph_edge_painter.dart`, todos en este mismo directorio — y este
/// archivo solo re-exporta esos tres para no tocar los `import` existentes.
library;

export 'animated_resource_graph.dart';
export 'graph_edge_painter.dart';
export 'graph_sort_controller.dart';
