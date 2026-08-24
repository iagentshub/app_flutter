part of '../pages/connections_page.dart';

extension _ConnectionsPageView on _ConnectionsPageState {
  Widget _buildPage(BuildContext context) {
    final tabLabels = [
      _tx('connections.tab_llm'),
      _tx('connections.tab_machine'),
      _tx('connections.tab_database'),
    ];

    final content = Column(
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
              final filteredConnections = _controller.filteredConnections;
              return RefreshIndicator(
                onRefresh: _controller.load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      sliver: SliverToBoxAdapter(
                        child: ResourceToolbar(
                          search: TextField(
                            controller: _controller.queryController,
                            decoration: InputDecoration(
                              labelText: _tx('connections.search_hint'),
                              prefixIcon: const Icon(Icons.search, size: 20),
                            ),
                            onChanged: _controller.setQuery,
                          ),
                          actions: [
                            AppIconButton.filled(
                              onPressed: _controller.providers.isEmpty
                                  ? null
                                  : _openCreateDialog,
                              icon: const Icon(Icons.add),
                              tooltip: _tx('connections.new'),
                            ),
                            AppIconButton.outlined(
                              onPressed: _controller.load,
                              icon: const Icon(Icons.refresh),
                              tooltip: _tx('common.update'),
                            ),
                            AppIconButton.outlined(
                              onPressed: _controller.testingAll
                                  ? null
                                  : _testAll,
                              tooltip: _controller.testingAll
                                  ? _tx('connections.testing')
                                  : _tx('connections.mass_test'),
                              icon: _controller.testingAll
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: IAgentsLoadingMark(),
                                    )
                                  : const Icon(Icons.play_circle_outline),
                            ),
                            FilterButton(
                              activeCount: _controller.activeFilterCount,
                              tooltip: _tx('common.filters'),
                              onPressed: _openFiltersDialog,
                            ),
                            AppIconButton.outlined(
                              onPressed: () => showGroupFilterDialog(
                                context,
                                apiClient: _services.apiClient,
                                token: _controller.token ?? '',
                                activeGroupId: _controller.activeGroupId,
                                onSelect: (groupId) =>
                                    unawaited(_controller.selectGroup(groupId)),
                                localeController: _services.localeController,
                              ),
                              icon: const Icon(Icons.groups_outlined),
                              tooltip: _tx('groups.toggle_tooltip'),
                              isSelected: _controller.activeGroupId != null,
                            ),
                            if (_controller.activeGroupId != null)
                              ActionChip(
                                label: Text(_tx('groups.active_clear')),
                                onPressed: () =>
                                    unawaited(_controller.selectGroup(null)),
                              ),
                          ],
                          summary: Text(
                            '${_tx('connections.count_label')}: ${filteredConnections.length} | ${_tx('connections.providers_label')}: ${_controller.providers.length}',
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
                                _controller.connections.isEmpty
                                    ? _tx('connections.empty')
                                    : _tx('connections.empty_search'),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      for (final group in _controller.connectionsByProvider)
                        ..._buildProviderGroupSlivers(group.key, group.value),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
    return IAgentsAsyncView(
      loading: _controller.loading,
      localeController: _services.localeController,
      error: _controller.error,
      errorTitle: _tx('connections.error_title'),
      retryLabel: _tx('common.retry'),
      onRetry: _controller.load,
      child: content,
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
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ),
      ResourceGridSliver(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildConnectionCard(items[index]),
      ),
    ];
  }

  Widget _buildConnectionCard(ConnectionItem item) {
    return ConnectionCard(
      item: item,
      tx: _tx,
      providerLabel: _controller.providerLabel(item.type),
      onTest: () => _testConnection(item),
      onShare: () => _shareConnection(item),
      onEdit: () => _openEditDialog(item),
      onDelete: () => _deleteConnection(item),
      testState: _statusDotFor(item.id),
      testMessage: _controller.testMessage(item.id),
      onToggleActive: (item.readOnly || item.isVirtual)
          ? null
          : () => _toggleConnectionActive(item),
      onSyncHub: item.type == 'iagentshub' ? () => _syncHub(item) : null,
    );
  }
}
