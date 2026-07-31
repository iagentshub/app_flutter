import 'package:flutter/material.dart';

import '../graph/graph_dialog.dart';
import '../graph/graph_models.dart';
import 'buttons/action_icon_button.dart';

/// Botón independiente que abre el grafo animado de contenido de un
/// recurso (skills, knowledge, conexión, memoria...). No conoce agentes ni
/// orquestaciones: quien lo usa arma [nodes]/[edges] a partir de su propio
/// modelo y se lo pasa ya listo.
class ResourceGraphButton extends StatelessWidget {
  const ResourceGraphButton({
    required this.tooltip,
    required this.dialogTitle,
    required this.nodes,
    required this.edges,
    required this.rootId,
    required this.closeLabel,
    required this.searchHint,
    required this.sortTooltip,
    required this.sortHierarchyVerticalLabel,
    required this.sortHierarchyHorizontalLabel,
    required this.sortRadialLabel,
    required this.quickViewDescriptionLabel,
    required this.quickViewNoDescriptionLabel,
    required this.quickViewConnectionsLabel,
    required this.quickViewNoConnectionsLabel,
    this.emptyLabel = '',
    super.key,
  });

  final String tooltip;
  final String dialogTitle;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String rootId;
  final String closeLabel;
  final String searchHint;
  final String sortTooltip;
  final String sortHierarchyVerticalLabel;
  final String sortHierarchyHorizontalLabel;
  final String sortRadialLabel;
  final String quickViewDescriptionLabel;
  final String quickViewNoDescriptionLabel;
  final String quickViewConnectionsLabel;
  final String quickViewNoConnectionsLabel;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return ActionIconButton(
      icon: Icons.hub_outlined,
      tooltip: tooltip,
      onPressed: () => showResourceGraphDialog(
        context: context,
        title: dialogTitle,
        nodes: nodes,
        edges: edges,
        rootId: rootId,
        closeLabel: closeLabel,
        searchHint: searchHint,
        sortTooltip: sortTooltip,
        sortHierarchyVerticalLabel: sortHierarchyVerticalLabel,
        sortHierarchyHorizontalLabel: sortHierarchyHorizontalLabel,
        sortRadialLabel: sortRadialLabel,
        quickViewDescriptionLabel: quickViewDescriptionLabel,
        quickViewNoDescriptionLabel: quickViewNoDescriptionLabel,
        quickViewConnectionsLabel: quickViewConnectionsLabel,
        quickViewNoConnectionsLabel: quickViewNoConnectionsLabel,
        emptyLabel: emptyLabel,
      ),
    );
  }
}
