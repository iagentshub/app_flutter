import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';
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
  required String sortTooltip,
  required String sortHierarchyVerticalLabel,
  required String sortHierarchyHorizontalLabel,
  required String sortGalaxyLabel,
  required String showLabelsTooltip,
  required String hideLabelsTooltip,
  required String quickViewDescriptionLabel,
  required String quickViewNoDescriptionLabel,
  required String quickViewConnectionsLabel,
  required String quickViewNoConnectionsLabel,
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
  });

  final String title;
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;
  final String rootId;
  final String closeLabel;
  final String searchHint;
  final String emptyLabel;
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

  @override
  State<_ResourceGraphDialogContent> createState() =>
      _ResourceGraphDialogContentState();
}

class _ResourceGraphDialogContentState
    extends State<_ResourceGraphDialogContent> {
  // Grafos grandes se abren directamente en modo galaxia (con nombres
  // ocultos) porque los layouts jerárquicos/radiales quedan amontonados a
  // partir de este tamaño; grafos pequeños siguen abriendo como antes.
  static const _autoGalaxyThreshold = 60;

  String _query = '';
  late final GraphSortController _sortController;
  late bool _showLabels;

  @override
  void initState() {
    super.initState();
    final initialMode = widget.nodes.length > _autoGalaxyThreshold
        ? GraphSortMode.galaxy
        : GraphSortMode.hierarchyVertical;
    _sortController = GraphSortController(initialMode);
    _showLabels = initialMode != GraphSortMode.galaxy;
    // El fondo del diálogo (ver `build`) depende del modo activo, así que
    // hay que reconstruir cuando cambie, no solo cuando se reabra el menú.
    _sortController.addListener(_handleSortModeChanged);
  }

  void _handleSortModeChanged() => setState(() {});

  @override
  void dispose() {
    _sortController.removeListener(_handleSortModeChanged);
    _sortController.dispose();
    super.dispose();
  }

  List<PopupMenuEntry<GraphSortMode>> _sortMenuItems() {
    return [
      _sortMenuItem(
        GraphSortMode.hierarchyVertical,
        widget.sortHierarchyVerticalLabel,
        Icons.vertical_align_bottom,
      ),
      _sortMenuItem(
        GraphSortMode.hierarchyHorizontal,
        widget.sortHierarchyHorizontalLabel,
        Icons.align_horizontal_left,
      ),
      _sortMenuItem(
        GraphSortMode.galaxy,
        widget.sortGalaxyLabel,
        Icons.blur_on,
      ),
    ];
  }

  PopupMenuItem<GraphSortMode> _sortMenuItem(
    GraphSortMode mode,
    String label,
    IconData icon,
  ) {
    final selected = _sortController.mode == mode;
    return PopupMenuItem<GraphSortMode>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          if (selected)
            const Icon(
              Icons.check_circle,
              size: 18,
              color: FncColors.materialGreen,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pantalla completa real (sin márgenes ni esquinas redondeadas de
    // diálogo) para aprovechar todo el espacio al explorar el grafo. En
    // modo galaxia, el fondo del diálogo entero (incluido el margen
    // alrededor del lienzo) usa el mismo negro que el resto de la app,
    // para que no quede un marco de un tono distinto rodeando el grafo.
    return Dialog.fullscreen(
      backgroundColor: _sortController.mode == GraphSortMode.galaxy
          ? Theme.of(context).scaffoldBackgroundColor
          : null,
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
                      fontSize: FncFonts.size20,
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
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: const TextStyle(fontSize: FncFonts.size13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      hintText: widget.searchHint,
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) => setState(() => _query = value.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: _showLabels
                      ? widget.hideLabelsTooltip
                      : widget.showLabelsTooltip,
                  icon: Icon(
                    _showLabels ? Icons.label : Icons.label_off_outlined,
                  ),
                  onPressed: () => setState(() => _showLabels = !_showLabels),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<GraphSortMode>(
                  tooltip: widget.sortTooltip,
                  icon: const Icon(Icons.sort),
                  onSelected: _sortController.setMode,
                  itemBuilder: (context) => _sortMenuItems(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedResourceGraph(
                nodes: widget.nodes,
                edges: widget.edges,
                rootId: widget.rootId,
                emptyLabel: widget.emptyLabel,
                highlightQuery: _query,
                showLabels: _showLabels,
                sortController: _sortController,
                quickViewDescriptionLabel: widget.quickViewDescriptionLabel,
                quickViewNoDescriptionLabel: widget.quickViewNoDescriptionLabel,
                quickViewConnectionsLabel: widget.quickViewConnectionsLabel,
                quickViewNoConnectionsLabel: widget.quickViewNoConnectionsLabel,
                quickViewCloseTooltip: widget.closeLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
