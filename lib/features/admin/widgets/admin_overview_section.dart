part of '../pages/admin_page.dart';

extension _AdminPageSections on _AdminPageState {
  Widget _buildGeneralTab() {
    final stats = _stats;
    if (stats == null) return const Center(child: Text('—'));
    final statItems = [
      (_tx('admin.stat_users', 'Usuarios'), stats.usersTotal),
      (_tx('admin.stat_active', 'Activos'), stats.usersActive),
      (_tx('admin.stat_verified', 'Verificados'), stats.usersVerified),
      (_tx('admin.stat_connections', 'Conexiones'), stats.connectionsTotal),
      (_tx('admin.stat_knowledge', 'Knowledge'), stats.knowledgeTotal),
      (_tx('admin.stat_workflows', 'Orquestaciones'), stats.workflowsTotal),
      (
        _tx('admin.stat_conversations', 'Conversaciones'),
        stats.conversationsTotal,
      ),
      (_tx('admin.stat_agents_public', 'Agentes públicos'), stats.agentsPublic),
      (
        _tx('admin.stat_agents_private', 'Agentes privados'),
        stats.agentsPrivate,
      ),
    ];
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: ResponsiveSliverMasonryGrid(
              density: ResponsiveCardDensity.compact,
              itemCount: statItems.length,
              itemBuilder: (context, index) =>
                  _statCard(statItems[index].$1, statItems[index].$2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, int value) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Usuarios ────────────────────────────────────────────────────

  /// Cuadrícula con construcción perezosa compartida por las pestañas
  /// tabulares de Admin: antes cada una era un `ListView` con
  /// `...items.map(cardBuilder)`, que construye TODAS las tarjetas de golpe
  /// en cada rebuild (cada tecla en el buscador) en vez de solo las
  /// visibles — con cientos de usuarios/recursos eso escala mal.
  /// Buscador ocupando toda la fila, con los botones de acción juntos en la
  /// fila de abajo — mismo patrón en todas las pestañas con listado.
  Widget _toolbar({Widget? search, required List<Widget> buttons}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (search != null) ...[search, const SizedBox(height: 10)],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: buttons,
        ),
      ],
    );
  }

  Widget _buildFilterableList({
    required Widget toolbar,
    required List<Map<String, dynamic>> items,
    required Widget Function(Map<String, dynamic>) itemBuilder,
    required String emptyText,
  }) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(child: toolbar),
          ),
          if (items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(child: _emptyCard(emptyText)),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: items.length,
                itemBuilder: (context, index) => itemBuilder(items[index]),
              ),
            ),
        ],
      ),
    );
  }
}
