part of '../pages/admin_page.dart';

extension _AdminExploreTab on _AdminPageState {
  String _resourceTypeLabel(AdminResourceType? type) {
    return switch (type) {
      AdminResourceType.user => _tx('admin.type_user', 'Usuario'),
      AdminResourceType.group => _tx('admin.type_group', 'Grupo'),
      AdminResourceType.agent => _tx('admin.type_agent', 'Agente'),
      AdminResourceType.connection => _tx('admin.type_connection', 'Conexión'),
      AdminResourceType.knowledge => _tx(
        'admin.type_knowledge',
        'Conocimiento',
      ),
      AdminResourceType.workflow => _tx('admin.type_workflow', 'Orquestación'),
      AdminResourceType.llmOrchestration => _tx(
        'admin.type_llm_orchestration',
        'Orquestación LLM',
      ),
      AdminResourceType.skill => _tx('admin.type_skill', 'Skill'),
      AdminResourceType.memory => _tx('admin.type_memory', 'Memoria'),
      AdminResourceType.prompt => _tx('admin.type_prompt', 'Prompt'),
      AdminResourceType.tool => _tx('admin.type_tool', 'Herramienta'),
      null => _tx('admin.type_all', 'Todos'),
    };
  }

  Color _resourceTypeColor(AdminResourceType type) {
    return switch (type) {
      AdminResourceType.user => FncColors.blue,
      AdminResourceType.group => FncColors.purple,
      AdminResourceType.agent => FncColors.danger,
      AdminResourceType.connection => FncColors.info,
      AdminResourceType.knowledge => FncColors.success,
      AdminResourceType.workflow => FncColors.labelDevelopment,
      AdminResourceType.llmOrchestration => FncColors.purple,
      AdminResourceType.skill => FncColors.labelSkill,
      AdminResourceType.memory => FncColors.labelMemory,
      AdminResourceType.prompt => FncColors.lime600,
      AdminResourceType.tool => FncColors.labelTool,
    };
  }

  Widget _resourceTypeBadge(AdminResourceType type) {
    return _badge(_resourceTypeLabel(type), _resourceTypeColor(type));
  }

  List<AdminExploreItem> get _filteredExploreItems {
    final allowed = <AdminResourceType, Set<String>>{
      AdminResourceType.user: _filteredUsers
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.group: _filteredGroups
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.agent: _filteredAgents
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.connection: _filteredConnections
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.knowledge: _filteredKnowledge
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.workflow: _filteredWorkflows
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.llmOrchestration: _llmOrchestrations
          .where(
            (item) =>
                _llmOrchestrationOwner.isEmpty ||
                _ownerOf(item) == _llmOrchestrationOwner,
          )
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.skill: _filteredSkills
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.memory: _filteredMemories
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.prompt: _filteredPrompts
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.tool: _filteredTools
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
    };
    return _exploreItems
        .where((item) {
          if (_exploreTypes.isNotEmpty && !_exploreTypes.contains(item.type)) {
            return false;
          }
          return allowed[item.type]?.contains(item.id) ?? false;
        })
        .toList(growable: false);
  }

  /// Los sub-filtros (propietario, tipo de knowledge...) son específicos de
  /// un tipo — solo tienen sentido cuando hay exactamente uno seleccionado.
  int get _exploreActiveFilterCount {
    if (_exploreTypes.length != 1) return 0;
    return switch (_exploreTypes.single) {
      AdminResourceType.user => _usersActiveFilterCount,
      AdminResourceType.agent => _agentOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.connection => _connOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.knowledge =>
        (_knowledgeType.isNotEmpty ? 1 : 0) +
            (_knowledgeOwner.isNotEmpty ? 1 : 0),
      AdminResourceType.workflow => _workflowOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.llmOrchestration =>
        _llmOrchestrationOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.skill => _skillOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.memory => _memoryOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.prompt => _promptOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.tool => _toolOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.group => 0,
    };
  }

  void _openExploreFilters() {
    if (_exploreTypes.length != 1) return;
    switch (_exploreTypes.single) {
      case AdminResourceType.user:
        _openUsersFiltersDialog();
      case AdminResourceType.agent:
        _openOwnerFilterDialog(
          owners: _ownersOf(_agents),
          currentOwner: _agentOwner,
          onChanged: (value) => refresh(() => _agentOwner = value),
        );
      case AdminResourceType.connection:
        _openOwnerFilterDialog(
          owners: _ownersOf(_connections),
          currentOwner: _connOwner,
          onChanged: (value) => refresh(() => _connOwner = value),
        );
      case AdminResourceType.knowledge:
        _openKnowledgeFiltersDialog();
      case AdminResourceType.workflow:
        _openOwnerFilterDialog(
          owners: _ownersOf(_workflows),
          currentOwner: _workflowOwner,
          onChanged: (value) => refresh(() => _workflowOwner = value),
        );
      case AdminResourceType.llmOrchestration:
        _openOwnerFilterDialog(
          owners: _ownersOf(_llmOrchestrations),
          currentOwner: _llmOrchestrationOwner,
          onChanged: (value) => refresh(() => _llmOrchestrationOwner = value),
        );
      case AdminResourceType.skill:
        _openOwnerFilterDialog(
          owners: _ownersOf(_skills),
          currentOwner: _skillOwner,
          onChanged: (value) => refresh(() => _skillOwner = value),
        );
      case AdminResourceType.memory:
        _openOwnerFilterDialog(
          owners: _ownersOf(_memories),
          currentOwner: _memoryOwner,
          onChanged: (value) => refresh(() => _memoryOwner = value),
        );
      case AdminResourceType.prompt:
        _openOwnerFilterDialog(
          owners: _ownersOf(_prompts),
          currentOwner: _promptOwner,
          onChanged: (value) => refresh(() => _promptOwner = value),
        );
      case AdminResourceType.tool:
        _openOwnerFilterDialog(
          owners: _ownersOf(_tools),
          currentOwner: _toolOwner,
          onChanged: (value) => refresh(() => _toolOwner = value),
        );
      case AdminResourceType.group:
        return;
    }
  }

  List<ExploreTypeOption> get _adminExploreTypeOptions => [
    for (final type in AdminResourceType.values)
      ExploreTypeOption(
        value: type.wireName,
        label: _resourceTypeLabel(type),
        icon: _resourceTypeIcon(type),
        color: _resourceTypeColor(type),
        count: _exploreCounts[type] ?? 0,
      ),
  ];

  Widget _buildExploreTab() {
    final items = _filteredExploreItems;
    return _buildFilterableList<AdminExploreItem>(
      items: items,
      itemBuilder: _buildExploreCard,
      emptyText: _tx(
        'admin.explore_empty',
        'No hay objetos que coincidan con los filtros',
      ),
      toolbar: ExploreSearchToolbar(
        searchController: _exploreSearchController,
        searchHint: _tx(
          'admin.explore_search_hint',
          'Buscar objetos por nombre, usuario o propietario',
        ),
        onSearchChanged: (_) => _onSearchChanged(),
        typeOptions: _adminExploreTypeOptions,
        selectedTypes: _exploreTypes.map((type) => type.wireName).toSet(),
        allTypesLabel: _tx('admin.type_all', 'Todos'),
        typeFilterTooltip: _tx('admin.explore_filter_type', 'Filtrar por tipo'),
        multipleTypesLabel: (count) => _tx(
          'admin.explore_types_selected',
          '{count} tipos',
        ).replaceAll('{count}', '$count'),
        onTypesChanged: (values) => refresh(() {
          _exploreTypes
            ..clear()
            ..addAll(values.map(AdminResourceType.fromWireName).whereType());
        }),
        selectorKey: const Key('exploreTypeDropdown'),
        actions: [
          AppIconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
          if ((_exploreTypes.isEmpty ||
                  _exploreTypes.contains(AdminResourceType.user)) &&
              (_platformSettings?['registration'] ?? 'open').toString() ==
                  'closed')
            AppIconButton.filled(
              onPressed: _openCreateUserDialog,
              icon: const Icon(Icons.add),
              tooltip: _tx('admin.users_new_btn', 'Nuevo usuario'),
            ),
          if (_exploreTypes.length == 1 &&
              _exploreTypes.single != AdminResourceType.group)
            FilterButton(
              activeCount: _exploreActiveFilterCount,
              tooltip: _tx('common.filters', 'Filtros'),
              onPressed: _openExploreFilters,
            ),
        ],
      ),
    );
  }

  IconData _resourceTypeIcon(AdminResourceType type) {
    return switch (type) {
      AdminResourceType.user => Icons.person_outline,
      AdminResourceType.group => Icons.groups_outlined,
      AdminResourceType.agent => Icons.smart_toy_outlined,
      AdminResourceType.connection => Icons.cable_outlined,
      AdminResourceType.knowledge => Icons.menu_book_outlined,
      AdminResourceType.workflow => Icons.account_tree_outlined,
      AdminResourceType.llmOrchestration => Icons.hub_outlined,
      AdminResourceType.skill => Icons.bolt_outlined,
      AdminResourceType.memory => Icons.description_outlined,
      AdminResourceType.prompt => Icons.chat_bubble_outline,
      AdminResourceType.tool => Icons.build_outlined,
    };
  }

  Widget _buildExploreCard(AdminExploreItem item) {
    if (item.data['is_official'] == true) return _buildAdminOfficialCard(item);
    return switch (item.type) {
      AdminResourceType.user => _buildUserCard(item.data),
      AdminResourceType.group => _buildGroupCard(item.data),
      AdminResourceType.agent => _buildAgentCard(item.data),
      AdminResourceType.connection => _buildAdminConnectionCard(item.data),
      AdminResourceType.knowledge => _buildAdminKnowledgeCard(item.data),
      AdminResourceType.workflow => _buildAdminWorkflowCard(item.data),
      AdminResourceType.llmOrchestration => _buildAdminLlmOrchestrationCard(
        item.data,
      ),
      AdminResourceType.skill => _buildAdminSkillCard(item.data),
      AdminResourceType.memory => _buildAdminMemoryCard(item.data),
      AdminResourceType.prompt => _buildAdminPromptCard(item.data),
      AdminResourceType.tool => _buildAdminToolCard(item.data),
    };
  }

  /// Componente de un paquete oficial publicado. No es una fila de la BD de
  /// recursos (vive en el catálogo hasta que alguien lo enlaza o copia), así
  /// que se pinta en modo lectura: sin borrar, sin cambiar propietario y sin
  /// grafo de relaciones. Lo que sí enseña son sus etiquetas reales, las
  /// mismas que Explorar.
  Widget _buildAdminOfficialCard(AdminExploreItem item) {
    final data = item.data;
    final name = (data['name'] ?? data['title'] ?? data['id'] ?? '').toString();
    final owner = _ownerOf(data);
    final packageName = (data['official_package_name'] ?? '').toString();
    final version = (data['official_version'] ?? '').toString();
    final description = (data['description'] ?? '').toString();
    // La versión llega tal cual la publica el paquete ("v1", "1.4.0"…), así
    // que se muestra sin prefijos añadidos.
    final source = [
      if (owner.isNotEmpty) owner,
      if (packageName.isNotEmpty) packageName,
      if (version.isNotEmpty) version,
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              source.isEmpty ? '—' : source,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _resourceTypeBadge(item.type),
                ..._labelBadges(data),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resourceGraphAction(
    AdminResourceType type,
    Map<String, dynamic> item,
  ) {
    return ActionIconButton(
      icon: Icons.hub_outlined,
      tooltip: _tx('admin.action_graph', 'Ver relaciones'),
      onPressed: () => _openResourceGraph(type, item),
    );
  }

  Future<void> _openResourceGraph(
    AdminResourceType type,
    Map<String, dynamic> item,
  ) async {
    final token = _token;
    final resourceId = (item['id'] ?? '').toString();
    if (token == null || resourceId.isEmpty) return;
    try {
      final graph = await _resourcesRepository.getResourceGraph(
        token,
        type,
        resourceId,
      );
      if (!mounted) return;
      await showResourceGraphDialog(
        context: context,
        title:
            '${_tx('admin.graph_title', 'Relaciones de')} ${_resourceTypeLabel(type).toLowerCase()}',
        nodes: graph.nodes,
        edges: graph.edges,
        rootId: graph.rootId,
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
          'Relaciones',
        ),
        quickViewNoConnectionsLabel: _tx(
          'graph.quick_view_no_connections',
          'Sin relaciones',
        ),
        emptyLabel: _tx('admin.graph_empty', 'Este objeto no tiene relaciones'),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('admin.graph_error', 'No se pudieron cargar las relaciones'),
        isError: true,
      );
    }
  }
}
