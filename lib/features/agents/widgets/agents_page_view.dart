part of '../pages/agents_page.dart';

extension _AgentsPageView on _AgentsPageState {
  Widget _buildPage(BuildContext context) {
    final filteredAgents = _filteredAgents;
    final content = ResourceCollectionView(
      compact: _compact,
      compactItemBuilder: (context, index) {
        final item = filteredAgents[index];
        final canChat =
            item.isActive &&
            item.connectionId.isNotEmpty &&
            !(_executionState?.isInProgress('agent', item.id) ?? false);
        return AgentCompactTile(
          item: item,
          details: _buildAgentCard(item),
          chatLabel: _tx('agents.chat_action'),
          inactiveLabel: _tx('common.inactive'),
          onChat: canChat ? () => _openChat(item) : null,
        );
      },
      onRefresh: _load,
      onLoadMore: _loadMoreAgents,
      hasMore: _hasMoreAgents,
      loadingMore: _loadingMoreAgents,
      header: ResourceToolbar(
        title: _tx('agents.header_title'),
        description: _tx('agents.header_description'),
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
        primaryAction: ResourceCreateButton(
          onPressed: _openCreateChoiceDialog,
          label: _tx('agents.new'),
        ),
        activeFilters: [
          if (_scope != 'all')
            InputChip(
              label: Text(
                _scope == 'public'
                    ? _tx('agents.scope_public')
                    : _tx('agents.scope_private'),
              ),
              onDeleted: () => refresh(() => _scope = 'all'),
            ),
          if (_agentType != 'all')
            InputChip(
              label: Text(_agentType),
              onDeleted: () => refresh(() => _agentType = 'all'),
            ),
          if (_memory != 'all')
            InputChip(
              label: Text(
                _tx(
                  _memory == 'with'
                      ? 'agents.memory_with'
                      : 'agents.memory_without',
                ),
              ),
              onDeleted: () => refresh(() => _memory = 'all'),
            ),
          if (_query.trim().isNotEmpty)
            InputChip(
              label: Text(_query),
              onDeleted: () {
                _queryController.clear();
                refresh(() => _query = '');
              },
            ),
        ],
        actions: [
          PopupMenuButton<AgentListOrder>(
            tooltip: _tx(_hasMoreAgents ? 'agents.sort_loaded' : 'agents.sort'),
            initialValue: _listOrder,
            onSelected: (value) => refresh(() => _listOrder = value),
            itemBuilder: (context) => [
              for (final order in AgentListOrder.values)
                CheckedPopupMenuItem(
                  value: order,
                  checked: _listOrder == order,
                  child: Text(_tx('agents.sort_${order.name}')),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _tx('agents.sort_${_listOrder.name}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
          AppIconButton.outlined(
            tooltip: _tx(
              _compact ? 'agents.view_cards' : 'agents.view_compact',
            ),
            isSelected: _compact,
            icon: Icon(
              _compact ? Icons.grid_view_outlined : Icons.view_list_outlined,
            ),
            onPressed: () => refresh(() => _compact = !_compact),
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
          '${_tx('agents.count_label')}: ${filteredAgents.length}'
          '${_hasMoreAgents ? '+' : ''}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
      // Dos situaciones distintas que antes se veían igual: no haber creado
      // nada todavía —donde la salida es crear el primero— y una búsqueda sin
      // resultados, que no se arregla creando nada.
      empty: _agents.isEmpty
          ? AsyncStatePanel.empty(
              padding: EdgeInsets.zero,
              icon: AppIcons.agents,
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
    final page = IAgentsAsyncView(
      loading: _loading,
      localeController: _services.localeController,
      error: _error,
      errorTitle: _tx('agents.error_title'),
      retryLabel: _tx('common.retry'),
      onRetry: _load,
      child: content,
    );
    return DropTarget(
      enable: !_importingAgentFile,
      onDragEntered: (_) => refresh(() => _draggingAgentFile = true),
      onDragExited: (_) => refresh(() => _draggingAgentFile = false),
      onDragDone: _handleAgentDrop,
      child: Stack(
        children: [
          page,
          if (_draggingAgentFile)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.12),
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      label: _tx('agents.import_drop_overlay'),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 22,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.upload_file_outlined),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  _tx('agents.import_drop_overlay'),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_importingAgentFile)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Theme.of(context).colorScheme.scrim
                      .withValues(alpha: 0.28),
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      label: _tx('agents.import_analyzing'),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 18,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const IAgentsLoadingMark(),
                              const SizedBox(width: 14),
                              Text(_tx('agents.import_analyzing')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(AgentItem item) {
    return AgentCard(
      item: item,
      inProgress: _executionState?.isInProgress('agent', item.id) ?? false,
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
