import 'dart:async';

import 'package:flutter/material.dart';

import '../graph/graph_dialog.dart';
import '../graph/resource_graph_builder.dart';
import 'buttons/action_icon_button.dart';

/// Botón independiente que abre el grafo animado de contenido de un
/// recurso (skills, knowledge, conexión, memoria...). No conoce agentes ni
/// orquestaciones: recibe [buildGraph], que arma el grafo con
/// `resource_graph_builder.dart`.
///
/// [buildGraph] es una función y no el grafo ya hecho **a propósito**: el
/// botón vive en cada tarjeta de una rejilla que se reconstruye al
/// desplazarse, y pasarle listas ya montadas obligaba a armar el grafo de
/// todos los recursos visibles en cada `build`, incluso sin abrir ninguno.
/// Aquí se arma al pulsar.
///
/// Puede ser asíncrona porque algunas pantallas necesitan datos que aún no
/// tienen —los nombres de los recursos que usa cada agente, los agentes que
/// usan un knowledge— y pedirlos al entrar en la pantalla era pagar una
/// llamada al backend por un grafo que casi nunca se abre.
class ResourceGraphButton extends StatelessWidget {
  const ResourceGraphButton({
    required this.tooltip,
    required this.dialogTitle,
    required this.buildGraph,
    required this.closeLabel,
    required this.searchHint,
    required this.sortTooltip,
    required this.sortHierarchyVerticalLabel,
    required this.sortHierarchyHorizontalLabel,
    required this.sortGalaxyLabel,
    required this.showLabelsTooltip,
    required this.hideLabelsTooltip,
    required this.quickViewDescriptionLabel,
    required this.quickViewNoDescriptionLabel,
    required this.quickViewConnectionsLabel,
    required this.quickViewNoConnectionsLabel,
    this.emptyLabel = '',
    super.key,
  });

  final String tooltip;
  final String dialogTitle;
  final FutureOr<GraphBuild> Function() buildGraph;
  final String closeLabel;
  final String searchHint;
  final String sortTooltip;
  final String sortHierarchyVerticalLabel;
  final String sortHierarchyHorizontalLabel;
  final String sortGalaxyLabel;
  final String showLabelsTooltip;
  final String hideLabelsTooltip;
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
      onPressed: () async {
        final graph = await buildGraph();
        if (!context.mounted) return;
        await showResourceGraphDialog(
          context: context,
          title: dialogTitle,
          nodes: graph.nodes,
          edges: graph.edges,
          rootId: graph.rootId,
          closeLabel: closeLabel,
          searchHint: searchHint,
          sortTooltip: sortTooltip,
          sortHierarchyVerticalLabel: sortHierarchyVerticalLabel,
          sortHierarchyHorizontalLabel: sortHierarchyHorizontalLabel,
          sortGalaxyLabel: sortGalaxyLabel,
          showLabelsTooltip: showLabelsTooltip,
          hideLabelsTooltip: hideLabelsTooltip,
          quickViewDescriptionLabel: quickViewDescriptionLabel,
          quickViewNoDescriptionLabel: quickViewNoDescriptionLabel,
          quickViewConnectionsLabel: quickViewConnectionsLabel,
          quickViewNoConnectionsLabel: quickViewNoConnectionsLabel,
          emptyLabel: emptyLabel,
        );
      },
    );
  }
}
