import 'package:flutter/material.dart';

import 'graph_models.dart';
import 'graph_view.dart';

/// Abre el grafo animado de contenido de un recurso en un diálogo, con un
/// buscador que resalta (parpadeando) los nodos coincidentes. No sabe nada
/// de agentes/orquestaciones: solo pinta los [nodes]/[edges] que le pasen,
/// así que sirve igual para cualquier tipo de recurso futuro.
Future<void> showResourceGraphDialog({
  required BuildContext context,
  required String title,
  required List<GraphNode> nodes,
  required List<GraphEdge> edges,
  required String rootId,
  required String closeLabel,
  required String searchHint,
  String emptyLabel = '',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _ResourceGraphDialogContent(
      title: title,
      nodes: nodes,
      edges: edges,
      rootId: rootId,
      closeLabel: closeLabel,
      searchHint: searchHint,
      emptyLabel: emptyLabel,
    ),
  );
}

class _ResourceGraphDialogContent extends StatefulWidget {
  const _ResourceGraphDialogContent({
    required this.title,
    required this.nodes,
    required this.edges,
    required this.rootId,
    required this.closeLabel,
    required this.searchHint,
    required this.emptyLabel,
  });

  final String title;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String rootId;
  final String closeLabel;
  final String searchHint;
  final String emptyLabel;

  @override
  State<_ResourceGraphDialogContent> createState() =>
      _ResourceGraphDialogContentState();
}

class _ResourceGraphDialogContentState
    extends State<_ResourceGraphDialogContent> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Pantalla completa real (sin márgenes ni esquinas redondeadas de
    // diálogo) para aprovechar todo el espacio al explorar el grafo.
    return Dialog.fullscreen(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: widget.closeLabel,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: widget.searchHint,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedResourceGraph(
                nodes: widget.nodes,
                edges: widget.edges,
                rootId: widget.rootId,
                emptyLabel: widget.emptyLabel,
                highlightQuery: _query,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
