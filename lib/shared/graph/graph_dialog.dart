import 'dart:async';

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

  /// Cada pulsación reconstruía el grafo entero: `didUpdateWidget` compara
  /// el grafo nuevo con el viejo y `_matches` se evalúa nodo a nodo, así que
  /// escribir «memoria» costaba siete rondas completas. Con la espera, una.
  static const _queryDebounce = Duration(milliseconds: 180);
  Timer? _queryTimer;

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
    _queryTimer?.cancel();
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
    final isGalaxy = _sortController.mode == GraphSortMode.galaxy;
    return PopupMenuItem<GraphSortMode>(
      value: mode,
      child: Row(
        children: [
          Icon(icon, size: 18, color: isGalaxy ? FncColors.galaxyStar : null),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: isGalaxy ? FncColors.white : null),
            ),
          ),
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
    final isGalaxy = _sortController.mode == GraphSortMode.galaxy;
    return Dialog.fullscreen(
      backgroundColor: isGalaxy ? FncColors.galaxyDeep : null,
      child: Padding(
        padding: EdgeInsets.all(isGalaxy ? 14 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, isGalaxy: isGalaxy),
            SizedBox(height: isGalaxy ? 12 : 8),
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

  Widget _buildHeader(BuildContext context, {required bool isGalaxy}) {
    final title = Row(
      children: [
        if (isGalaxy) ...[
          const Icon(Icons.blur_on, color: FncColors.galaxyStar, size: 20),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: FncFonts.size20,
              fontWeight: FontWeight.w700,
              color: isGalaxy ? FncColors.white : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isGalaxy) ...[
          _galaxyMetric(
            icon: Icons.circle_outlined,
            value: widget.nodes.length,
            semanticLabel: '${widget.title}: ${widget.nodes.length}',
          ),
          const SizedBox(width: 6),
          _galaxyMetric(
            icon: Icons.timeline,
            value: widget.edges.length,
            semanticLabel:
                '${widget.quickViewConnectionsLabel}: ${widget.edges.length}',
          ),
          const SizedBox(width: 4),
        ],
        IconButton(
          icon: const Icon(Icons.close),
          color: isGalaxy ? FncColors.galaxyStar : null,
          tooltip: widget.closeLabel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );

    final controls = Row(
      children: [
        Expanded(
          child: TextField(
            style: TextStyle(
              fontSize: FncFonts.size13,
              color: isGalaxy ? FncColors.white : null,
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: isGalaxy,
              fillColor: isGalaxy ? FncColors.galaxySurfaceStrong : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
              prefixIcon: Icon(
                Icons.search,
                size: 18,
                color: isGalaxy ? FncColors.galaxyTextMuted : null,
              ),
              hintText: widget.searchHint,
              hintStyle: isGalaxy
                  ? const TextStyle(color: FncColors.galaxyTextMuted)
                  : null,
              enabledBorder: isGalaxy
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: FncColors.galaxyBorder,
                      ),
                    )
                  : const OutlineInputBorder(),
              focusedBorder: isGalaxy
                  ? OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: FncColors.blue),
                    )
                  : const OutlineInputBorder(),
            ),
            onChanged: (value) {
              final query = value.trim();
              if (query == _query) return;
              _queryTimer?.cancel();
              // Borrar del todo se aplica ya: el usuario espera ver el grafo
              // entero de vuelta en cuanto vacía el campo.
              if (query.isEmpty) {
                setState(() => _query = '');
                return;
              }
              _queryTimer = Timer(_queryDebounce, () {
                if (mounted) setState(() => _query = query);
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: _showLabels
              ? widget.hideLabelsTooltip
              : widget.showLabelsTooltip,
          color: isGalaxy ? FncColors.galaxyStar : null,
          style: isGalaxy
              ? IconButton.styleFrom(
                  backgroundColor: FncColors.galaxySurfaceStrong,
                  side: const BorderSide(color: FncColors.galaxyBorder),
                )
              : null,
          icon: Icon(_showLabels ? Icons.label : Icons.label_off_outlined),
          onPressed: () => setState(() => _showLabels = !_showLabels),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<GraphSortMode>(
          tooltip: widget.sortTooltip,
          color: isGalaxy ? FncColors.galaxySurfaceStrong : null,
          iconColor: isGalaxy ? FncColors.galaxyStar : null,
          style: isGalaxy
              ? IconButton.styleFrom(
                  backgroundColor: FncColors.galaxySurfaceStrong,
                  side: const BorderSide(color: FncColors.galaxyBorder),
                )
              : null,
          icon: const Icon(Icons.tune),
          onSelected: _sortController.setMode,
          itemBuilder: (context) => _sortMenuItems(),
        ),
      ],
    );

    if (!isGalaxy) {
      return Column(children: [title, const SizedBox(height: 8), controls]);
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [FncColors.galaxySurface, FncColors.galaxySurfaceStrong],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FncColors.galaxyBorder),
        boxShadow: [
          BoxShadow(
            color: FncColors.materialBlack.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(children: [title, const SizedBox(height: 6), controls]),
    );
  }

  Widget _galaxyMetric({
    required IconData icon,
    required int value,
    required String semanticLabel,
  }) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: FncColors.galaxyDeep.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FncColors.galaxyBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: FncColors.galaxyTextMuted),
            const SizedBox(width: 5),
            Text(
              '$value',
              style: const TextStyle(
                color: FncColors.galaxyStar,
                fontSize: FncFonts.size11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
