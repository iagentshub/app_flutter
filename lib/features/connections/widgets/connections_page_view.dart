part of '../pages/connections_page.dart';

extension _ConnectionsPageView on _ConnectionsPageState {
  Widget _buildPage(BuildContext context) {
    if (_loading) {
      return const AsyncStatePanel.loading();
    }

    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('connections.error_title', 'Error cargando conexiones'),
            message: _error!,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _load,
          ),
        ],
      );
    }

    final tabLabels = [
      _tx('connections.tab_llm', 'APIs LLM'),
      _tx('connections.tab_machine', 'Máquinas'),
      _tx('connections.tab_database', 'Bases de datos'),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: FncColors.transparent,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final filteredConnections = _filteredConnections;
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
                              labelText: _tx(
                                'connections.search_hint',
                                'Buscar conexión',
                              ),
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
                              onPressed: _providers.isEmpty
                                  ? null
                                  : _openCreateDialog,
                              icon: const Icon(Icons.add),
                              tooltip: _tx('connections.new', 'Nueva conexión'),
                            ),
                            AppIconButton.outlined(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              tooltip: _tx('common.update', 'Actualizar'),
                            ),
                            AppIconButton.outlined(
                              onPressed: _testingAll ? null : _testAll,
                              tooltip: _testingAll
                                  ? _tx('connections.testing', 'Probando...')
                                  : _tx('connections.mass_test', 'Test masivo'),
                              icon: _testingAll
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.play_circle_outline),
                            ),
                            FilterButton(
                              activeCount: _activeFilterCount,
                              tooltip: _tx('common.filters', 'Filtros'),
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
                              tooltip: _tx('groups.toggle_tooltip', 'Grupos'),
                              isSelected: _activeGroupId != null,
                            ),
                            if (_activeGroupId != null)
                              ActionChip(
                                label: Text(
                                  _tx('groups.active_clear', 'Grupo activo ✕'),
                                ),
                                onPressed: () => _onGroupSelect(null),
                              ),
                          ],
                          summary: Text(
                            '${_tx('connections.count_label', 'Conexiones')}: ${filteredConnections.length} | ${_tx('connections.providers_label', 'Proveedores')}: ${_providers.length}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                    if (filteredConnections.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        sliver: SliverToBoxAdapter(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _connections.isEmpty
                                    ? _tx(
                                        'connections.empty',
                                        'No hay conexiones todavía. Crea la primera.',
                                      )
                                    : _tx(
                                        'connections.empty_search',
                                        'Sin resultados para esa búsqueda.',
                                      ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      for (final group in _connectionsByProvider)
                        ..._buildProviderGroupSlivers(group.key, group.value),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<Widget> _buildProviderGroupSlivers(
    String providerLabel,
    List<ConnectionItem> items,
  ) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            '$providerLabel (${items.length})',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        sliver: ResponsiveSliverMasonryGrid(
          itemCount: items.length,
          itemBuilder: (context, index) => _buildConnectionCard(items[index]),
        ),
      ),
    ];
  }

  Widget _buildConnectionCard(ConnectionItem item) {
    return ConnectionCard(
      item: item,
      tx: _tx,
      providerLabel: _providerLabel(item.type),
      onTest: () => _testConnection(item),
      onShare: () => _shareConnection(item),
      onEdit: () => _openEditDialog(item),
      onDelete: () => _deleteConnection(item),
      testState: _testStatus[item.id],
      testMessage: _testMessages[item.id],
      onToggleActive: (item.readOnly || item.isVirtual)
          ? null
          : () => _toggleConnectionActive(item),
      onSyncHub: item.type == 'iagentshub' ? () => _syncHub(item) : null,
    );
  }
}
