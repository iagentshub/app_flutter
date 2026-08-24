part of '../pages/explore_page.dart';

extension _ExploreCollectionViews on _ExplorePageState {
  Widget _buildResourcesTab() {
    final error = _controller.error;
    if (error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tx('explore.error_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(error),
                  const SizedBox(height: 12),
                  PrimaryButton.icon(
                    onPressed: _controller.load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_controller.loading) {
      return const Center(child: IAgentsLoadingMark());
    }

    return _buildScrollView();
  }

  Widget _buildScrollView() {
    final items = _controller.items;
    final packs = _controller.officialPacks;
    return ResourceCollectionView(
      onRefresh: _controller.load,
      gridPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      header: ExploreSearchToolbar(
        searchController: _controller.queryController,
        searchHint: _tx('explore.search_hint'),
        onSearchSubmitted: (_) => _controller.load(),
        typeOptions: _publicExploreTypeOptions,
        selectedTypes: _controller.type == 'all'
            ? const <String>{}
            : {_controller.type},
        allTypesLabel: _tx('explore.type_all'),
        typeFilterTooltip: _tx('explore.type_filter_tooltip'),
        multipleTypesLabel: (count) => '$count',
        allowMultipleTypes: false,
        selectorKey: const Key('publicExploreTypeDropdown'),
        onTypesChanged: (values) =>
            _controller.setType(values.firstOrNull ?? 'all'),
        actions: [
          FilterButton(
            activeCount: _controller.secondaryActiveFilterCount,
            tooltip: _tx('explore.more_filters_tooltip'),
            onPressed: _openFiltersDialog,
          ),
        ],
      ),
      leadingSlivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${_tx('explore.results')}: ${_controller.resultCount}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
      ],
      empty: _buildResourcesEmpty(),
      itemCount: packs.length + items.length,
      itemBuilder: (context, index) => index < packs.length
          ? _buildOfficialPackCard(packs[index])
          : _buildItemCard(items[index - packs.length]),
      trailingSlivers: [
        if (_controller.resourcesHasMore)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: _controller.resourcesLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: IAgentsLoadingMark(),
                      )
                    : SecondaryButton(
                        onPressed: () =>
                            _runAction(_controller.loadMoreResources()),
                        child: Text(_tx('explore.load_more')),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  /// El vacío tiene que explicarse cuando lo ha causado el propio filtro: si
  /// «Nuevos» se queda sin resultados pero la búsqueda sí encuentra cosas que
  /// ya tienes, un «no hay resultados» a secas parece un buscador roto.
  Widget _buildResourcesEmpty() {
    final linkedMatches = _controller.linkedMatches;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              linkedMatches > 0
                  ? _tx('explore.empty_all_linked')
                        .replaceAll('{count}', '$linkedMatches')
                  : _tx('explore.empty'),
            ),
            if (linkedMatches > 0) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                onPressed: () =>
                    _controller.setRelation(ExploreRelation.enlazado),
                child: Text(_tx('explore.empty_show_linked')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsersTab() {
    final error = _controller.usersError;
    if (error != null) {
      return AsyncStatePanel.error(
        title: _tx('explore.users_error_title'),
        message: error,
        retryLabel: _tx('common.retry'),
        onRetry: _controller.loadUsers,
      );
    }

    if (_controller.usersLoading) {
      return const Center(child: IAgentsLoadingMark());
    }

    return _buildUsersScrollView();
  }

  Widget _buildUsersScrollView() {
    final users = _controller.users;
    return ResourceCollectionView(
      onRefresh: _controller.loadUsers,
      gridPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      density: ResponsiveCardDensity.compact,
      header: TextField(
        controller: _controller.userQueryController,
        decoration: InputDecoration(
          labelText: _tx('explore.users_search_hint'),
          prefixIcon: const Icon(Icons.search, size: 20),
        ),
        onChanged: (_) => _controller.onUserSearchChanged(),
      ),
      empty: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(_tx('explore.users_empty')),
        ),
      ),
      itemCount: users.length,
      itemBuilder: (context, index) => _buildUserCard(users[index]),
      trailingSlivers: [
        if (users.isNotEmpty && _controller.usersHasMore)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: _controller.usersLoadingMore
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: IAgentsLoadingMark(),
                      )
                    : SecondaryButton(
                        onPressed: () =>
                            _runAction(_controller.loadMoreUsers()),
                        child: Text(_tx('explore.users_load_more')),
                      ),
              ),
            ),
          ),
      ],
    );
  }
}
