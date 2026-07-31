/// Modelo genérico de grafo, desacoplado de agentes/orquestaciones: quien
/// use [ResourceGraphButton] arma sus propios [GraphNode]/[GraphEdge] a
/// partir del recurso que sea. `type` se usa para colorear el nodo con
/// `labelColor` (mismas claves que el catálogo de etiquetas: agent, skill,
/// knowledge, connection, memory, workflow...).
class GraphNode {
  const GraphNode({
    required this.id,
    required this.label,
    required this.type,
    this.description = '',
  });

  final String id;
  final String label;
  final String type;
  final String description;
}

class GraphEdge {
  const GraphEdge({
    required this.sourceId,
    required this.targetId,
    this.dashed = false,
  });

  final String sourceId;
  final String targetId;

  /// Marca conexiones "especiales" (p. ej. un bucle en una orquestación)
  /// para que se dibujen distinto de una conexión secuencial normal.
  final bool dashed;
}
