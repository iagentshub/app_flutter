part of '../pages/agents_page.dart';

extension _AgentsPageView on _AgentsPageState {
  Widget _buildPage(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('agents.error_title'),
            message: _error!,
            retryLabel: _tx('common.retry'),
            onRetry: _load,
          ),
        ],
      );
    }

    final filteredAgents = _filteredAgents;
    return ResourceCollectionView(
      onRefresh: _load,
      header: ResourceToolbar(
        search: TextField(
          controller: _queryController,
          decoration: InputDecoration(
            labelText: _tx('agents.search_hint'),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (value) {
            _query = value;
            _searchDebouncer.run(() {
              if (mounted) refresh(() {});
            });
          },
        ),
        actions: [
          AppIconButton.filled(
            onPressed: _openCreateChoiceDialog,
            icon: const Icon(Icons.add),
            tooltip: _tx('agents.new'),
          ),
          AppIconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('common.update'),
          ),
          FilterButton(
            activeCount: _activeFilterCount,
            tooltip: _tx('common.filters'),
            onPressed: _openFiltersDialog,
          ),
          AppIconButton.outlined(
            onPressed: () => showGroupFilterDialog(
              context,
              apiClient: _services.apiClient,
              token: _token ?? '',
              activeGroupId: _activeGroupId,
              onSelect: _onGroupSelect,
              localeController: _services.localeController,
            ),
            icon: const Icon(Icons.groups_outlined),
            tooltip: _tx('groups.toggle_tooltip'),
            isSelected: _activeGroupId != null,
          ),
          if (_activeGroupId != null)
            ActionChip(
              label: Text(_tx('groups.active_clear')),
              onPressed: () => _onGroupSelect(null),
            ),
        ],
        summary: Text(
          '${_tx('agents.count_label')}: ${filteredAgents.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      // Dos situaciones distintas que antes se veían igual: no haber creado
      // nada todavía —donde la salida es crear el primero— y una búsqueda sin
      // resultados, que no se arregla creando nada.
      empty: _agents.isEmpty
          ? AsyncStatePanel.empty(
              padding: EdgeInsets.zero,
              icon: Icons.smart_toy_outlined,
              title: _tx('agents.empty_title'),
              message: _tx('agents.empty'),
              actionLabel: _tx('agents.empty_action'),
              onAction: _openCreateChoiceDialog,
            )
          : AsyncStatePanel.empty(
              padding: EdgeInsets.zero,
              icon: Icons.search_off,
              title: _tx('agents.empty_search_title'),
              message: _tx('agents.empty_search'),
            ),
      itemCount: filteredAgents.length,
      itemBuilder: (context, index) => _buildAgentCard(filteredAgents[index]),
    );
  }

  Widget _buildAgentCard(AgentItem item) {
    return AgentCard(
      item: item,
      skillNames: _skillNames,
      knowledgeNames: _knowledgeNames,
      knowledgePackNames: _knowledgePackNames,
      knowledgePackItems: _knowledgePackItems,
      promptNames: _promptNames,
      toolNames: _toolNames,
      connectionNames: _connectionNames,
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
