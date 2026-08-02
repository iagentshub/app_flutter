part of '../pages/admin_page.dart';

extension _AdminPageSections on _AdminPageState {
  String? _pctOfTotal(int part, int total) {
    if (total <= 0) return null;
    final pct = (part / total * 100).round();
    return _tx(
      'admin.stat_pct_of_total',
      '{pct}% del total',
    ).replaceAll('{pct}', '$pct');
  }

  Widget _buildGeneralTab() {
    final stats = _stats;
    if (stats == null) return const Center(child: Text('—'));
    final agentsTotal = stats.agentsPublic + stats.agentsPrivate;
    final scheme = Theme.of(context).colorScheme;

    final statItems =
        <
          ({
            String label,
            int value,
            IconData icon,
            Color tint,
            String? subtitle,
          })
        >[
          (
            label: _tx('admin.stat_users', 'Usuarios'),
            value: stats.usersTotal,
            icon: Icons.people_alt_outlined,
            tint: scheme.primary,
            subtitle: null,
          ),
          (
            label: _tx('admin.stat_active', 'Activos'),
            value: stats.usersActive,
            icon: Icons.bolt_outlined,
            tint: scheme.primary,
            subtitle: _pctOfTotal(stats.usersActive, stats.usersTotal),
          ),
          (
            label: _tx('admin.stat_verified', 'Verificados'),
            value: stats.usersVerified,
            icon: Icons.verified_outlined,
            tint: scheme.primary,
            subtitle: _pctOfTotal(stats.usersVerified, stats.usersTotal),
          ),
          (
            label: _tx('admin.stat_connections', 'Conexiones'),
            value: stats.connectionsTotal,
            icon: Icons.hub_outlined,
            tint: scheme.secondary,
            subtitle: null,
          ),
          (
            label: _tx('admin.stat_knowledge', 'Knowledge'),
            value: stats.knowledgeTotal,
            icon: Icons.menu_book_outlined,
            tint: scheme.secondary,
            subtitle: null,
          ),
          (
            label: _tx('admin.stat_workflows', 'Orquestaciones'),
            value: stats.workflowsTotal,
            icon: Icons.account_tree_outlined,
            tint: scheme.secondary,
            subtitle: null,
          ),
          (
            label: _tx('admin.stat_conversations', 'Conversaciones'),
            value: stats.conversationsTotal,
            icon: Icons.forum_outlined,
            tint: scheme.tertiary,
            subtitle: null,
          ),
          (
            label: _tx('admin.stat_agents_public', 'Agentes públicos'),
            value: stats.agentsPublic,
            icon: Icons.public,
            tint: scheme.tertiary,
            subtitle: _pctOfTotal(stats.agentsPublic, agentsTotal),
          ),
          (
            label: _tx('admin.stat_agents_private', 'Agentes privados'),
            value: stats.agentsPrivate,
            icon: Icons.lock_outline,
            tint: scheme.tertiary,
            subtitle: _pctOfTotal(stats.agentsPrivate, agentsTotal),
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
              minCardWidth: 190,
              itemCount: statItems.length,
              itemBuilder: (context, index) {
                final item = statItems[index];
                return _statCard(
                  label: item.label,
                  value: item.value,
                  icon: item.icon,
                  tint: item.tint,
                  subtitle: item.subtitle,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String label,
    required int value,
    required IconData icon,
    required Color tint,
    String? subtitle,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
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
