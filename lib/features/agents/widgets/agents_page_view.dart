part of '../pages/agents_page.dart';

extension _AgentsPageView on _AgentsPageState {
  Widget _buildPage(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('agents.error_title', 'Error cargando agentes'),
            message: _error!,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _load,
          ),
        ],
      );
    }

    final filteredAgents = _filteredAgents;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: ResourceToolbar(
                search: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    labelText: _tx('agents.search_hint', 'Buscar agente'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                  onChanged: (value) {
                    _query = value;
                    _searchDebouncer.run(() {
                      if (mounted) _refresh(() {});
                    });
                  },
                ),
                actions: [
                  AppIconButton.filled(
                    onPressed: _openCreateChoiceDialog,
                    icon: const Icon(Icons.add),
                    tooltip: _tx('agents.new', 'Nuevo agente'),
                  ),
                  AppIconButton.outlined(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: _tx('common.update', 'Actualizar'),
                  ),
                  FilterButton(
                    activeCount: _activeFilterCount,
                    tooltip: _tx('common.filters', 'Filtros'),
                    onPressed: _openFiltersDialog,
                  ),
                  AppIconButton.outlined(
                    onPressed: () => showGroupFilterDialog(
                      context,
                      apiClient: widget.apiClient,
                      token: _token ?? '',
                      activeGroupId: _activeGroupId,
                      onSelect: _onGroupSelect,
                      localeController: widget.localeController,
                    ),
                    icon: const Icon(Icons.groups_outlined),
                    tooltip: _tx('groups.toggle_tooltip', 'Grupos'),
                    isSelected: _activeGroupId != null,
                  ),
                  if (_activeGroupId != null)
                    ActionChip(
                      label: Text(_tx('groups.active_clear', 'Grupo activo ✕')),
                      onPressed: () => _onGroupSelect(null),
                    ),
                ],
                summary: Text(
                  '${_tx('agents.count_label', 'Agentes')}: ${filteredAgents.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          if (filteredAgents.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _agents.isEmpty
                          ? _tx('agents.empty', 'No hay agentes disponibles.')
                          : _tx(
                              'agents.empty_search',
                              'Sin resultados para esa búsqueda.',
                            ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: filteredAgents.length,
                itemBuilder: (context, index) =>
                    _buildAgentCard(filteredAgents[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(AgentItem item) {
    return AgentCard(
      item: item,
      skillNames: _skillNames,
      knowledgeNames: _knowledgeNames,
      tx: _tx,
      onChat: () => _openChat(item),
      onExport: (format) => _exportAgent(item, format),
      onShare: () => _shareAgent(item),
      onHistory: () => _showHistory(item),
      onEdit: () => _openEditDialog(item),
      onDelete: () => _deleteAgent(item),
      onToggleActive: item.readOnly ? null : () => _toggleAgentActive(item),
    );
  }
}

/// Selector de agente público a usar como plantilla, con búsqueda por nombre.
