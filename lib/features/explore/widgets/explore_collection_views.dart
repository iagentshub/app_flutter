part of '../pages/explore_page.dart';

extension _ExploreCollectionViews on _ExplorePageState {
  Widget _buildResourcesTab() {
    if (_error != null) {
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
                    _tx('explore.error_title', 'Error cargando Explore'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  PrimaryButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry', 'Reintentar')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(onRefresh: _load, child: _buildScrollView());
  }

  Widget _buildScrollView() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    labelText: _tx('explore.search_hint', 'Buscar'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                  onSubmitted: (_) => _load(),
                ),
                const SizedBox(height: 10),
                FilterButton(
                  activeCount: _activeFilterCount,
                  tooltip: _tx('common.filters', 'Filtros'),
                  onPressed: _openFiltersDialog,
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Text(
              '${_tx('explore.results', 'Resultados')}: ${_items.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        if (_items.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _tx('explore.empty', 'No hay resultados para ese filtro.'),
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: ResponsiveSliverMasonryGrid(
              itemCount: _items.length,
              itemBuilder: (context, index) => _buildItemCard(_items[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildUsersTab() {
    if (_usersError != null) {
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
                    _tx('explore.users_error_title', 'No se pudo cargar'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_usersError!),
                  const SizedBox(height: 12),
                  PrimaryButton.icon(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry', 'Reintentar')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_usersLoading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _loadUsers,
      child: _buildUsersScrollView(),
    );
  }

  Widget _buildUsersScrollView() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _userQueryController,
              decoration: InputDecoration(
                labelText: _tx('explore.users_search_hint', 'Buscar usuarios'),
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (_) => _onUserSearchChanged(),
            ),
          ),
        ),
        if (_users.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _tx('explore.users_empty', 'No se encontraron usuarios.'),
                  ),
                ),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: ResponsiveSliverMasonryGrid(
              density: ResponsiveCardDensity.compact,
              itemCount: _users.length,
              itemBuilder: (context, index) => _buildUserCard(_users[index]),
            ),
          ),
          if (_usersHasMore)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: _usersLoadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : SecondaryButton(
                          onPressed: _loadMoreUsers,
                          child: Text(
                            _tx('explore.users_load_more', 'Cargar más'),
                          ),
                        ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
