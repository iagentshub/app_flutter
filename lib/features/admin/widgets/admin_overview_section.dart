part of '../pages/admin_page.dart';

extension _AdminPageSections on _AdminPageState {
  Widget _buildGeneralTab() {
    final stats = _stats;
    if (stats == null) return const Center(child: Text('—'));
    final agentsTotal = stats.agentsPublic + stats.agentsPrivate;
    final scheme = Theme.of(context).colorScheme;
    final publicPct = agentsTotal > 0 ? stats.agentsPublic / agentsTotal : 0.0;
    final privatePct = agentsTotal > 0
        ? stats.agentsPrivate / agentsTotal
        : 0.0;

    final statItems =
        <
          ({
            String label,
            int value,
            IconData icon,
            Color tint,
            double? progress,
          })
        >[
          (
            label: _tx('admin.stat_connections', 'Conexiones'),
            value: stats.connectionsTotal,
            icon: Icons.hub_outlined,
            tint: scheme.secondary,
            progress: null,
          ),
          (
            label: _tx('admin.stat_knowledge', 'Knowledge'),
            value: stats.knowledgeTotal,
            icon: Icons.menu_book_outlined,
            tint: scheme.secondary,
            progress: null,
          ),
          (
            label: _tx('admin.stat_workflows', 'Orquestaciones'),
            value: stats.workflowsTotal,
            icon: Icons.account_tree_outlined,
            tint: scheme.secondary,
            progress: null,
          ),
          (
            label: _tx('admin.stat_conversations', 'Conversaciones'),
            value: stats.conversationsTotal,
            icon: Icons.forum_outlined,
            tint: scheme.tertiary,
            progress: null,
          ),
          (
            label: _tx('admin.stat_agents_public', 'Agentes públicos'),
            value: stats.agentsPublic,
            icon: Icons.public,
            tint: scheme.tertiary,
            progress: publicPct,
          ),
          (
            label: _tx('admin.stat_agents_private', 'Agentes privados'),
            value: stats.agentsPrivate,
            icon: Icons.lock_outline,
            tint: scheme.tertiary,
            progress: privatePct,
          ),
        ];
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(child: _usersHeroCard(stats, scheme)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            sliver: ResponsiveSliverMasonryGrid(
              minCardWidth: 190,
              itemCount: statItems.length,
              itemBuilder: (context, index) {
                final item = statItems[index];
                return _statCard(
                  label: item.label,
                  value: item.value,
                  icon: item.icon,
                  tint: item.tint,
                  progress: item.progress,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta protagonista: el total de usuarios a gran tamaño junto con dos
  /// anillos compactos (activos/verificados como % de ese total) — resume el
  /// estado de la base de usuarios de un vistazo antes del resto de KPIs.
  Widget _usersHeroCard(AdminStats stats, ColorScheme scheme) {
    final activePct = stats.usersTotal > 0
        ? stats.usersActive / stats.usersTotal
        : 0.0;
    final verifiedPct = stats.usersTotal > 0
        ? stats.usersVerified / stats.usersTotal
        : 0.0;

    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _tx('admin.stat_users', 'Usuarios'),
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '${stats.usersTotal}',
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
    );

    final rings = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _heroRing(
          pct: activePct,
          label: _tx('admin.stat_active', 'Activos'),
          color: scheme.primary,
        ),
        const SizedBox(width: 20),
        _heroRing(
          pct: verifiedPct,
          label: _tx('admin.stat_verified', 'Verificados'),
          color: scheme.tertiary,
        ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 360) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [headline, const SizedBox(height: 18), rings],
              );
            }
            return Row(
              children: [
                Expanded(child: headline),
                rings,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heroRing({
    required double pct,
    required String label,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ArcGauge(
          progress: pct,
          color: color,
          size: 56,
          strokeWidth: 5,
          child: Text(
            '${(pct * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required int value,
    required IconData icon,
    required Color tint,
    double? progress,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (progress != null)
              ArcGauge(
                progress: progress,
                color: tint,
                size: 40,
                strokeWidth: 4,
                child: Icon(icon, size: 16, color: tint),
              )
            else
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: tint),
              ),
            const SizedBox(height: 12),
            Text(
              '$value',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (progress != null) ...[
              const SizedBox(height: 2),
              Text(
                _tx(
                  'admin.stat_pct_of_total',
                  '{pct}% del total',
                ).replaceAll('{pct}', '${(progress * 100).round()}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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

  Widget _buildFilterableList<T>({
    required Widget toolbar,
    required List<T> items,
    required Widget Function(T) itemBuilder,
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
