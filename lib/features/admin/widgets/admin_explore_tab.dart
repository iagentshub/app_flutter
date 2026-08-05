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
      AdminResourceType.skill => _tx('admin.type_skill', 'Skill'),
      AdminResourceType.memory => _tx('admin.type_memory', 'Memoria'),
      AdminResourceType.prompt => _tx('admin.type_prompt', 'Prompt'),
      null => _tx('admin.type_all', 'Todos'),
    };
  }

  Color _resourceTypeColor(AdminResourceType type) {
    return switch (type) {
      AdminResourceType.user => const Color(0xFF2563EB),
      AdminResourceType.group => const Color(0xFF7C3AED),
      AdminResourceType.agent => const Color(0xFFDC2626),
      AdminResourceType.connection => const Color(0xFF0891B2),
      AdminResourceType.knowledge => const Color(0xFF059669),
      AdminResourceType.workflow => const Color(0xFFD97706),
      AdminResourceType.skill => const Color(0xFF9333EA),
      AdminResourceType.memory => const Color(0xFFB45309),
      AdminResourceType.prompt => const Color(0xFF65A30D),
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
      AdminResourceType.skill: _filteredSkills
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.memory: _filteredMemories
          .map((item) => (item['id'] ?? '').toString())
          .toSet(),
      AdminResourceType.prompt: _filteredPrompts
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
      AdminResourceType.skill => _skillOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.memory => _memoryOwner.isNotEmpty ? 1 : 0,
      AdminResourceType.prompt => _promptOwner.isNotEmpty ? 1 : 0,
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
          onChanged: (value) => _refresh(() => _agentOwner = value),
        );
      case AdminResourceType.connection:
        _openOwnerFilterDialog(
          owners: _ownersOf(_connections),
          currentOwner: _connOwner,
          onChanged: (value) => _refresh(() => _connOwner = value),
        );
      case AdminResourceType.knowledge:
        _openKnowledgeFiltersDialog();
      case AdminResourceType.workflow:
        _openOwnerFilterDialog(
          owners: _ownersOf(_workflows),
          currentOwner: _workflowOwner,
          onChanged: (value) => _refresh(() => _workflowOwner = value),
        );
      case AdminResourceType.skill:
        _openOwnerFilterDialog(
          owners: _ownersOf(_skills),
          currentOwner: _skillOwner,
          onChanged: (value) => _refresh(() => _skillOwner = value),
        );
      case AdminResourceType.memory:
        _openOwnerFilterDialog(
          owners: _ownersOf(_memories),
          currentOwner: _memoryOwner,
          onChanged: (value) => _refresh(() => _memoryOwner = value),
        );
      case AdminResourceType.prompt:
        _openOwnerFilterDialog(
          owners: _ownersOf(_prompts),
          currentOwner: _promptOwner,
          onChanged: (value) => _refresh(() => _promptOwner = value),
        );
      case AdminResourceType.group:
        return;
    }
  }

  /// Botón tipo "desplegable" que abre un menú con una casilla por tipo
  /// (más "Todos" para volver de un tirón al conjunto vacío = sin filtro).
  /// Un `PopupMenuItem` único y `enabled: false` para que el menú no se
  /// cierre al marcar cada casilla — solo el `StatefulBuilder` interno se
  /// repinta, y `_refresh` mantiene la lista filtrada en vivo por debajo.
  Widget _exploreTypeDropdown() {
    final scheme = Theme.of(context).colorScheme;
    final totalCount = _exploreCounts.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final label = _exploreTypes.isEmpty
        ? '${_tx('admin.type_all', 'Todos')} ($totalCount)'
        : _exploreTypes.length == 1
        ? _resourceTypeLabel(_exploreTypes.single)
        : _tx(
            'admin.explore_types_selected',
            '{count} tipos',
          ).replaceAll('{count}', '${_exploreTypes.length}');

    return PopupMenuButton<void>(
      key: const Key('exploreTypeDropdown'),
      tooltip: _tx('admin.explore_filter_type', 'Filtrar por tipo'),
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          enabled: false,
          padding: EdgeInsets.zero,
          child: StatefulBuilder(
            builder: (context, setMenuState) => SizedBox(
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _exploreTypes.isEmpty,
                    title: Text(
                      '${_tx('admin.type_all', 'Todos')} ($totalCount)',
                    ),
                    onChanged: (_) {
                      setMenuState(() => _exploreTypes.clear());
                      _refresh(() {});
                    },
                  ),
                  const Divider(height: 1),
                  for (final type in AdminResourceType.values)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _exploreTypes.contains(type),
                      secondary: Icon(
                        _resourceTypeIcon(type),
                        size: 18,
                        color: _resourceTypeColor(type),
                      ),
                      title: Text(
                        '${_resourceTypeLabel(type)} (${_exploreCounts[type] ?? 0})',
                      ),
                      onChanged: (checked) {
                        setMenuState(() {
                          if (checked == true) {
                            _exploreTypes.add(type);
                          } else {
                            _exploreTypes.remove(type);
                          }
                        });
                        _refresh(() {});
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
      child: IntrinsicWidth(
        child: InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            border: OutlineInputBorder(),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExploreTab() {
    final items = _filteredExploreItems;
    return _buildFilterableList<AdminExploreItem>(
      items: items,
      itemBuilder: _buildExploreCard,
      emptyText: _tx(
        'admin.explore_empty',
        'No hay objetos que coincidan con los filtros',
      ),
      toolbar: _toolbar(
        search: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _exploreSearchController,
                decoration: InputDecoration(
                  labelText: _tx(
                    'admin.explore_search_hint',
                    'Buscar objetos por nombre, usuario o propietario',
                  ),
                  prefixIcon: const Icon(Icons.search, size: 20),
                ),
                onChanged: (_) => _onSearchChanged(),
              ),
            ),
            const SizedBox(width: 8),
            _exploreTypeDropdown(),
          ],
        ),
        buttons: [
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
      AdminResourceType.skill => Icons.bolt_outlined,
      AdminResourceType.memory => Icons.description_outlined,
      AdminResourceType.prompt => Icons.chat_bubble_outline,
    };
  }

  Widget _buildExploreCard(AdminExploreItem item) {
    return switch (item.type) {
      AdminResourceType.user => _buildUserCard(item.data),
      AdminResourceType.group => _buildGroupCard(item.data),
      AdminResourceType.agent => _buildAgentCard(item.data),
      AdminResourceType.connection => _buildAdminConnectionCard(item.data),
      AdminResourceType.knowledge => _buildAdminKnowledgeCard(item.data),
      AdminResourceType.workflow => _buildAdminWorkflowCard(item.data),
      AdminResourceType.skill => _buildAdminSkillCard(item.data),
      AdminResourceType.memory => _buildAdminMemoryCard(item.data),
      AdminResourceType.prompt => _buildAdminPromptCard(item.data),
    };
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
      final graph = await _repository.getResourceGraph(token, type, resourceId);
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
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('admin.graph_error', 'No se pudieron cargar las relaciones'),
        isError: true,
      );
    }
  }
}
