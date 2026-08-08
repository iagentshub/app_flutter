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
                    _tx('explore.error_title', 'Error cargando Explore'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(error),
                  const SizedBox(height: 12),
                  PrimaryButton.icon(
                    onPressed: _controller.load,
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

    if (_controller.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _controller.load,
      child: _buildScrollView(),
    );
  }

  Widget _buildScrollView() {
    final items = _controller.items;
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
                  controller: _controller.queryController,
                  decoration: InputDecoration(
                    labelText: _tx('explore.search_hint', 'Buscar'),
                    prefixIcon: const Icon(Icons.search, size: 20),
                  ),
                  onSubmitted: (_) => _controller.load(),
                ),
                const SizedBox(height: 10),
                FilterButton(
                  activeCount: _controller.activeFilterCount,
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
              '${_tx('explore.results', 'Resultados')}: ${items.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        if (items.isEmpty)
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
              itemCount: items.length,
              itemBuilder: (context, index) => _buildItemCard(items[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildUsersTab() {
    final error = _controller.usersError;
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
                    _tx('explore.users_error_title', 'No se pudo cargar'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(error),
                  const SizedBox(height: 12),
                  PrimaryButton.icon(
                    onPressed: _controller.loadUsers,
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

    if (_controller.usersLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _controller.loadUsers,
      child: _buildUsersScrollView(),
    );
  }

  Widget _buildUsersScrollView() {
    final users = _controller.users;
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: TextField(
              controller: _controller.userQueryController,
              decoration: InputDecoration(
                labelText: _tx('explore.users_search_hint', 'Buscar usuarios'),
                prefixIcon: const Icon(Icons.search, size: 20),
              ),
              onChanged: (_) => _controller.onUserSearchChanged(),
            ),
          ),
        ),
        if (users.isEmpty)
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
              itemCount: users.length,
              itemBuilder: (context, index) => _buildUserCard(users[index]),
            ),
          ),
          if (_controller.usersHasMore)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: _controller.usersLoadingMore
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : SecondaryButton(
                          onPressed: () =>
                              _runAction(_controller.loadMoreUsers()),
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
