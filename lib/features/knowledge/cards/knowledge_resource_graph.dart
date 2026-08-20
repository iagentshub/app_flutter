part of '../pages/knowledge_page.dart';

extension _KnowledgeResourceGraph on _KnowledgePageState {
  /// Agentes que pueden aparecer en un grafo de esta pantalla, cargados la
  /// primera vez que se abre uno.
  ///
  /// Antes se pedían en `initState`: una llamada al backend, con todos los
  /// agentes del grupo incluidos los inactivos, para decidir qué relaciones
  /// dibujaría un grafo que la mayoría de las visitas a Knowledge no abre.
  Future<List<AgentItem>> _loadGraphRelations() {
    return _graphRelations ??= () async {
      final token = _token;
      if (token == null || token.isEmpty) return const <AgentItem>[];
      try {
        return await _agentsRepository.listAgents(
          token,
          groupId: _activeGroupId,
        );
      } catch (_) {
        // Sin agentes el grafo sigue teniendo sentido: enseña el recurso y su
        // pack. Se olvida el fallo para reintentar al siguiente grafo.
        _graphRelations = null;
        return const <AgentItem>[];
      }
    }();
  }

  /// Descarta el catálogo cacheado: al cambiar de grupo los agentes visibles
  /// son otros.
  void _invalidateGraphRelations() => _graphRelations = null;

  bool _agentUsesResource(AgentItem agent, String type, String id) {
    return switch (type) {
      'skill' => agent.skills.contains(id),
      'prompt' => agent.prompts.contains(id),
      'tool' => agent.tools.contains(id),
      'knowledge' => agent.knowledge.contains(id),
      'knowledge_pack' => agent.knowledgePacks.contains(id),
      _ => false,
    };
  }

  Widget _buildResourceGraphButton({
    required String resourceId,
    required String resourceName,
    required String resourceType,
    String resourceDescription = '',
  }) {
    return _graphButton(
      resourceName,
      () async => resourceUsageGraph(
        resourceId: resourceId,
        resourceName: resourceName,
        resourceType: resourceType,
        resourceDescription: resourceDescription,
        usedBy: (await _loadGraphRelations())
            .where(
              (agent) => _agentUsesResource(agent, resourceType, resourceId),
            )
            .toList(),
      ),
    );
  }

  Widget _buildKnowledgeItemGraphButton(KnowledgeItem item) {
    final packId = item.packId;
    return _graphButton(
      item.name,
      () async => knowledgeItemGraph(
        item: item,
        pack: packId == null || packId.isEmpty
            ? null
            : _packs.where((candidate) => candidate.id == packId).firstOrNull,
        usedBy: (await _loadGraphRelations())
            .where(
              (agent) =>
                  agent.knowledge.contains(item.id) ||
                  (packId != null && agent.knowledgePacks.contains(packId)),
            )
            .toList(),
      ),
    );
  }

  Widget _buildKnowledgePackGraphButton(KnowledgePack pack) {
    return _graphButton(
      pack.name,
      () async => knowledgePackGraph(
        pack: pack,
        items: _items.where((item) => item.packId == pack.id).toList(),
        usedBy: await _loadGraphRelations(),
      ),
    );
  }

  Widget _graphButton(
    String resourceName,
    Future<GraphBuild> Function() buildGraph,
  ) {
    return ResourceGraphButton(
      tooltip: _tx('knowledge.graph_tooltip'),
      dialogTitle: _tx(
        'knowledge.graph_title',
      ).replaceAll('{{name}}', resourceName),
      buildGraph: buildGraph,
      closeLabel: _tx('common.close'),
      searchHint: _tx('graph.search_hint'),
      sortTooltip: _tx('graph.sort_tooltip'),
      sortHierarchyVerticalLabel: _tx('graph.sort_hierarchy_vertical'),
      sortHierarchyHorizontalLabel: _tx('graph.sort_hierarchy_horizontal'),
      sortGalaxyLabel: _tx('graph.sort_galaxy'),
      showLabelsTooltip: _tx('graph.show_labels_tooltip'),
      hideLabelsTooltip: _tx('graph.hide_labels_tooltip'),
      quickViewDescriptionLabel: _tx('graph.quick_view_description'),
      quickViewNoDescriptionLabel: _tx('graph.quick_view_no_description'),
      quickViewConnectionsLabel: _tx('graph.quick_view_connections'),
      quickViewNoConnectionsLabel: _tx('graph.quick_view_no_connections'),
      emptyLabel: _tx('knowledge.graph_empty'),
    );
  }
}
