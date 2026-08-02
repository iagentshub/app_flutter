part of '../pages/admin_page.dart';

extension _AdminPageSections on _AdminPageState {
  String _pctLabel(double progress) => _tx(
    'admin.stat_pct_of_total',
    '{pct}% del total',
  ).replaceAll('{pct}', '${(progress * 100).round()}');

  static const _healthOkColor = Color(0xFF059669);

  /// Verde si la métrica está sana, el color de error del tema si no —
  /// las KPI de recursos usan tinte decorativo por afinidad, pero estas son
  /// literalmente un semáforo de estado y deben leerse como tal.
  Color _healthColor(BuildContext context, bool healthy) =>
      healthy ? _healthOkColor : Theme.of(context).colorScheme.error;

  Widget _buildGeneralTab() {
    final stats = _stats;
    if (stats == null) return const Center(child: Text('—'));
    final agentsTotal = stats.agentsPublic + stats.agentsPrivate;
    final scheme = Theme.of(context).colorScheme;
    final activePct = stats.usersTotal > 0
        ? stats.usersActive / stats.usersTotal
        : 0.0;
    final verifiedPct = stats.usersTotal > 0
        ? stats.usersVerified / stats.usersTotal
        : 0.0;
    final publicPct = agentsTotal > 0 ? stats.agentsPublic / agentsTotal : 0.0;
    final privatePct = agentsTotal > 0
        ? stats.agentsPrivate / agentsTotal
        : 0.0;

    final tiles = <KpiTile>[
      KpiTile(
        label: _tx('admin.stat_connections', 'Conexiones'),
        value: stats.connectionsTotal,
        icon: Icons.hub_outlined,
        tint: scheme.secondary,
      ),
      KpiTile(
        label: _tx('admin.stat_knowledge', 'Knowledge'),
        value: stats.knowledgeTotal,
        icon: Icons.menu_book_outlined,
        tint: scheme.secondary,
      ),
      KpiTile(
        label: _tx('admin.stat_workflows', 'Orquestaciones'),
        value: stats.workflowsTotal,
        icon: Icons.account_tree_outlined,
        tint: scheme.secondary,
      ),
      KpiTile(
        label: _tx('admin.stat_conversations', 'Conversaciones'),
        value: stats.conversationsTotal,
        icon: Icons.forum_outlined,
        tint: scheme.tertiary,
      ),
      KpiTile(
        label: _tx('admin.stat_agents_public', 'Agentes públicos'),
        value: stats.agentsPublic,
        icon: Icons.public,
        tint: scheme.tertiary,
        progress: publicPct,
        progressLabel: _pctLabel(publicPct),
      ),
      KpiTile(
        label: _tx('admin.stat_agents_private', 'Agentes privados'),
        value: stats.agentsPrivate,
        icon: Icons.lock_outline,
        tint: scheme.tertiary,
        progress: privatePct,
        progressLabel: _pctLabel(privatePct),
      ),
    ];

    final noErrorsToday = stats.errorsToday == 0;
    final healthTiles = <KpiTile>[
      KpiTile(
        label: _tx('admin.stat_requests_today', 'Peticiones hoy'),
        value: stats.requestsToday,
        icon: Icons.swap_horiz,
        tint: scheme.primary,
      ),
      KpiTile(
        label: _tx('admin.stat_errors_today', 'Errores hoy'),
        value: stats.errorsToday,
        icon: Icons.error_outline,
        tint: _healthColor(context, noErrorsToday),
      ),
      KpiTile(
        label: _tx('admin.stat_failure_rate', '% de fallo'),
        value: stats.failureRatePct.round(),
        icon: Icons.percent,
        tint: _healthColor(context, stats.failureRatePct == 0),
        unit: '%',
      ),
      KpiTile(
        label: _tx('admin.stat_avg_latency', 'Latencia media'),
        value: stats.avgLatencyMs,
        icon: Icons.speed_outlined,
        tint: scheme.secondary,
        unit: 'ms',
      ),
      KpiTile(
        label:
            stats.topErrorEndpoint ??
            _tx('admin.stat_no_errors_today', 'Sin fallos hoy'),
        value: stats.topErrorCount,
        icon: Icons.report_gmailerrorred_outlined,
        tint: _healthColor(context, noErrorsToday),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            sliver: SliverToBoxAdapter(
              child: KpiHeroCard(
                title: _tx('admin.stat_users', 'Usuarios'),
                value: stats.usersTotal,
                rings: [
                  KpiHeroRing(
                    progress: activePct,
                    label: _tx('admin.stat_active', 'Activos'),
                    color: scheme.primary,
                  ),
                  KpiHeroRing(
                    progress: verifiedPct,
                    label: _tx('admin.stat_verified', 'Verificados'),
                    color: scheme.tertiary,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: ResponsiveSliverMasonryGrid(
              minCardWidth: 190,
              itemCount: tiles.length,
              itemBuilder: (context, index) => tiles[index],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            sliver: SliverToBoxAdapter(
              child: Text(
                _tx('admin.stat_section_health', 'Estado de la aplicación'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            sliver: ResponsiveSliverMasonryGrid(
              minCardWidth: 190,
              itemCount: healthTiles.length,
              itemBuilder: (context, index) => healthTiles[index],
            ),
          ),
        ],
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
