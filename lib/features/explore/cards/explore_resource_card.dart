part of '../pages/explore_page.dart';

extension _ExploreResourceCard on _ExplorePageState {
  static const _linkableTypes = {
    'agent',
    'skill',
    'prompt',
    'tool',
    'knowledge',
    'workflow',
  };

  Widget _buildItemCard(ExploreItem item) {
    final busy =
        _controller.isBusy(item) || _officialBusyKeys.contains(item.resourceId);
    final myUsername = _services.sessionController.user?.username ?? '';
    final isOwn = myUsername.isNotEmpty && item.ownerUsername == myUsername;
    final isLinkable = !isOwn && _linkableTypes.contains(item.resourceType);
    final linked = _controller.isLinked(item);
    final starred = _controller.isStarred(item);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  item.isOfficial
                      ? Icons.source_outlined
                      : Icons.person_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.isOfficial
                        ? item.officialPackageName
                        : item.ownerUsername,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                if (item.isOfficial) ...[
                  Icon(
                    Icons.star,
                    size: 17,
                    color: FncColors.warning,
                    semanticLabel: _tx('official.badge', 'Oficial'),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _tx('official.badge', 'Oficial'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Icon(
                    Icons.bookmark_outline,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${item.stars}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: item.labels,
              labelText: (label) => _tx('labels.$label', label),
              leading: [
                ResourceTypeBadge(
                  type: item.resourceType,
                  label: _typeChipLabel(item.resourceType),
                ),
                _chip(_categoryChipLabel(item.category)),
              ],
            ),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags
                    .take(4)
                    .map((tag) => _miniChip('#$tag'))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: _tx('explore.preview', 'Vista previa'),
                  onPressed: busy ? null : () => _preview(item),
                ),
                if (item.isOfficial && item.dependencies.isNotEmpty)
                  _officialGraphButton(item),
                if (item.isOfficial) ...[
                  if (item.hubInstallable)
                    ActionIconButton(
                      icon: Icons.add_circle_outline,
                      tooltip: _tx('official.use', 'Usar recurso oficial'),
                      onPressed: busy ? null : () => _useOfficialResource(item),
                    ),
                  ActionIconButton(
                    icon: Icons.download_outlined,
                    tooltip: _tx('official.export', 'Exportar'),
                    onPressed: busy
                        ? null
                        : () => _downloadOfficialResource(item),
                  ),
                ] else if (isLinkable)
                  ActionIconButton(
                    icon: linked ? Icons.link : Icons.link_outlined,
                    tooltip: linked
                        ? _tx('explore.linked_tooltip', 'Ya enlazado')
                        : _tx('explore.link', 'Enlazar'),
                    onPressed: (busy || linked)
                        ? null
                        : () => _runAction(_controller.link(item)),
                  ),
                const Spacer(),
                if (!item.isOfficial)
                  ActionIconButton(
                    icon: starred ? Icons.bookmark : Icons.bookmark_outline,
                    tooltip: starred
                        ? _tx('explore.unstar', 'Quitar de favoritos')
                        : _tx('explore.star', 'Añadir a favoritos'),
                    onPressed: busy
                        ? null
                        : () => _runAction(_controller.toggleStar(item)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _officialGraphButton(ExploreItem item) {
    final rootId = 'official:${item.resourceId}';
    final nodes = <GraphNode>[
      GraphNode(
        id: rootId,
        label: item.name,
        type: item.resourceType,
        description: item.description,
      ),
      for (final dependency in item.dependencies)
        GraphNode(
          id: 'official:${item.officialPackageId}:${dependency.componentId}',
          label: dependency.name,
          type: dependency.type,
        ),
    ];
    final edges = <GraphEdge>[
      for (final dependency in item.dependencies)
        if (item.directDependencyIds.contains(dependency.componentId))
          GraphEdge(
            sourceId: rootId,
            targetId:
                'official:${item.officialPackageId}:${dependency.componentId}',
          ),
      for (final dependency in item.dependencies)
        for (final nestedId in dependency.dependencies)
          GraphEdge(
            sourceId:
                'official:${item.officialPackageId}:${dependency.componentId}',
            targetId: 'official:${item.officialPackageId}:$nestedId',
          ),
    ];
    return ResourceGraphButton(
      tooltip: _tx('agents.graph_tooltip', 'Ver grafo de contenido'),
      dialogTitle: item.name,
      nodes: nodes,
      edges: edges,
      rootId: rootId,
      closeLabel: _tx('common.close', 'Cerrar'),
      searchHint: _tx('graph.search_hint', 'Buscar en el grafo...'),
      sortTooltip: _tx('graph.sort_tooltip', 'Ordenar'),
      sortHierarchyVerticalLabel: _tx(
        'graph.sort_hierarchy_vertical',
        'Jerarquía vertical',
      ),
      sortHierarchyHorizontalLabel: _tx(
        'graph.sort_hierarchy_horizontal',
        'Jerarquía horizontal',
      ),
      sortGalaxyLabel: _tx('graph.sort_galaxy', 'Galaxia'),
      showLabelsTooltip: _tx('graph.show_labels_tooltip', 'Mostrar etiquetas'),
      hideLabelsTooltip: _tx('graph.hide_labels_tooltip', 'Ocultar etiquetas'),
      quickViewDescriptionLabel: _tx(
        'graph.quick_view_description',
        'Descripción',
      ),
      quickViewNoDescriptionLabel: _tx(
        'graph.quick_view_no_description',
        'Sin descripción',
      ),
      quickViewConnectionsLabel: _tx(
        'graph.quick_view_connections',
        'Conexiones',
      ),
      quickViewNoConnectionsLabel: _tx(
        'graph.quick_view_no_connections',
        'Sin conexiones',
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FncColors.materialBlack.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: FncFonts.size12)),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FncColors.materialBlack.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: FncFonts.size11)),
    );
  }
}
