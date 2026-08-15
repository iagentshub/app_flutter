part of '../pages/knowledge_page.dart';

extension _KnowledgeResourceGraph on _KnowledgePageState {
  Future<void> _loadGraphRelations() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final generation = ++_graphRelationsGeneration;
    try {
      final agents = await _agentsRepository.listAgents(
        token,
        groupId: _activeGroupId,
        includeInactive: true,
      );
      if (!mounted || generation != _graphRelationsGeneration) return;
      refresh(() => _relatedAgents = agents);
    } catch (_) {
      if (!mounted || generation != _graphRelationsGeneration) return;
      refresh(() => _relatedAgents = const []);
    }
  }

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

  GraphNode _agentGraphNode(AgentItem agent) => GraphNode(
    id: 'agent-${agent.id}',
    label: agent.name,
    type: 'agent',
    description: agent.description,
  );

  Widget _buildResourceGraphButton({
    required String resourceId,
    required String resourceName,
    required String resourceType,
    String resourceDescription = '',
  }) {
    final agents = _relatedAgents
        .where((agent) => _agentUsesResource(agent, resourceType, resourceId))
        .toList();
    final nodes = <GraphNode>[
      GraphNode(
        id: 'root',
        label: resourceName,
        type: resourceType,
        description: resourceDescription,
      ),
      ...agents.map(_agentGraphNode),
    ];
    final edges = [
      for (final agent in agents)
        GraphEdge(sourceId: 'root', targetId: 'agent-${agent.id}'),
    ];
    return _graphButton(resourceName, nodes, edges);
  }

  Widget _buildKnowledgeItemGraphButton(KnowledgeItem item) {
    final nodes = <GraphNode>[
      GraphNode(
        id: 'root',
        label: item.name,
        type: 'knowledge',
        description: item.preview,
      ),
    ];
    final edges = <GraphEdge>[];
    final packId = item.packId;
    if (packId != null && packId.isNotEmpty) {
      final pack = _packs
          .where((candidate) => candidate.id == packId)
          .firstOrNull;
      nodes.add(
        GraphNode(
          id: 'pack-$packId',
          label: pack?.name ?? item.packRelativePath,
          type: 'knowledge_pack',
          description: pack?.description ?? '',
        ),
      );
      edges.add(GraphEdge(sourceId: 'pack-$packId', targetId: 'root'));
    }
    for (final agent in _relatedAgents.where(
      (agent) =>
          agent.knowledge.contains(item.id) ||
          (packId != null && agent.knowledgePacks.contains(packId)),
    )) {
      nodes.add(_agentGraphNode(agent));
      edges.add(GraphEdge(sourceId: 'root', targetId: 'agent-${agent.id}'));
    }
    return _graphButton(item.name, nodes, edges);
  }

  Widget _buildKnowledgePackGraphButton(KnowledgePack pack) {
    final items = _items.where((item) => item.packId == pack.id).toList();
    final nodesById = <String, GraphNode>{
      'root': GraphNode(
        id: 'root',
        label: pack.name,
        type: 'knowledge_pack',
        description: pack.description,
      ),
    };
    final edges = <GraphEdge>[];
    final edgeKeys = <String>{};

    void addEdge(String sourceId, String targetId) {
      if (edgeKeys.add('$sourceId->$targetId')) {
        edges.add(GraphEdge(sourceId: sourceId, targetId: targetId));
      }
    }

    for (final item in items) {
      final itemNodeId = 'knowledge-${item.id}';
      nodesById[itemNodeId] = GraphNode(
        id: itemNodeId,
        label: item.packRelativePath.isEmpty
            ? item.name
            : item.packRelativePath,
        type: 'knowledge',
        description: item.preview,
      );
      addEdge('root', itemNodeId);
    }

    for (final agent in _relatedAgents) {
      final agentNodeId = 'agent-${agent.id}';
      if (agent.knowledgePacks.contains(pack.id)) {
        nodesById[agentNodeId] = _agentGraphNode(agent);
        addEdge('root', agentNodeId);
      }
      for (final item in items.where(
        (candidate) => agent.knowledge.contains(candidate.id),
      )) {
        nodesById[agentNodeId] = _agentGraphNode(agent);
        addEdge('knowledge-${item.id}', agentNodeId);
      }
    }
    return _graphButton(pack.name, nodesById.values.toList(), edges);
  }

  Widget _graphButton(
    String resourceName,
    List<GraphNode> nodes,
    List<GraphEdge> edges,
  ) {
    return ResourceGraphButton(
      tooltip: _tx('knowledge.graph_tooltip', 'Ver relaciones'),
      dialogTitle: _tx(
        'knowledge.graph_title',
        'Relaciones de {{name}}',
      ).replaceAll('{{name}}', resourceName),
      nodes: nodes,
      edges: edges,
      rootId: 'root',
      closeLabel: _tx('common.close', 'Cerrar'),
      searchHint: _tx('graph.search_hint', 'Buscar en el grafo...'),
      sortTooltip: _tx('graph.sort_tooltip', 'Ordenar'),
      sortHierarchyVerticalLabel: _tx(
        'graph.sort_hierarchy_vertical',
        'Jerárquico (arriba-abajo)',
      ),
      sortHierarchyHorizontalLabel: _tx(
        'graph.sort_hierarchy_horizontal',
        'Jerárquico (izquierda-derecha)',
      ),
      sortGalaxyLabel: _tx('graph.sort_galaxy', 'Galaxia'),
      showLabelsTooltip: _tx('graph.show_labels_tooltip', 'Mostrar nombres'),
      hideLabelsTooltip: _tx('graph.hide_labels_tooltip', 'Ocultar nombres'),
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
      emptyLabel: _tx(
        'knowledge.graph_empty',
        'Este objeto no tiene relaciones',
      ),
    );
  }
}
