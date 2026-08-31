part of '../pages/admin_page.dart';

extension _AdminPageSections on _AdminPageState {
  String _pctLabel(double progress) =>
      _tx('admin.stat_pct_of_total')
          .replaceAll('{pct}', '${(progress * 100).round()}');

  static const _healthOkColor = FncColors.success;

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
    // El cupo del demo. A 0 el modo invitado está apagado y la tarjeta no
    // aporta nada; con tope, el anillo dice cuánto queda antes del 503.
    final guestPct = stats.guestsMax > 0
        ? (stats.guestsActive / stats.guestsMax).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final publicPct = agentsTotal > 0 ? stats.agentsPublic / agentsTotal : 0.0;
    final privatePct = agentsTotal > 0
        ? stats.agentsPrivate / agentsTotal
        : 0.0;

    final tiles = <KpiTile>[
      KpiTile(
        label: _tx('admin.stat_connections'),
        value: stats.connectionsTotal,
        icon: Icons.hub_outlined,
        tint: scheme.secondary,
      ),
      KpiTile(
        label: _tx('admin.stat_knowledge'),
        value: stats.knowledgeTotal,
        icon: Icons.menu_book_outlined,
        tint: scheme.secondary,
      ),
      KpiTile(
        label: _tx('admin.stat_workflows'),
        value: stats.workflowsTotal,
        icon: Icons.account_tree_outlined,
        tint: scheme.secondary,
      ),
      KpiTile(
        label: _tx('admin.stat_conversations'),
        value: stats.conversationsTotal,
        icon: Icons.forum_outlined,
        tint: scheme.tertiary,
      ),
      if (stats.guestsMax > 0)
        KpiTile(
          label: _tx('admin.stat_guests'),
          value: stats.guestsActive,
          icon: Icons.person_outline,
          tint: scheme.secondary,
          progress: guestPct,
          progressLabel: '${stats.guestsActive}/${stats.guestsMax}',
        ),
      KpiTile(
        label: _tx('admin.stat_agents_public'),
        value: stats.agentsPublic,
        icon: Icons.public,
        tint: scheme.tertiary,
        progress: publicPct,
        progressLabel: _pctLabel(publicPct),
      ),
      KpiTile(
        label: _tx('admin.stat_agents_private'),
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
        label: _tx('admin.stat_requests_today'),
        value: stats.requestsToday,
        icon: Icons.swap_horiz,
        tint: scheme.primary,
      ),
      KpiTile(
        label: _tx('admin.stat_errors_today'),
        value: stats.errorsToday,
        icon: Icons.error_outline,
        tint: _healthColor(context, noErrorsToday),
      ),
      KpiTile(
        label: _tx('admin.stat_failure_rate'),
        value: stats.failureRatePct.round(),
        icon: Icons.percent,
        tint: _healthColor(context, stats.failureRatePct == 0),
        unit: '%',
      ),
      KpiTile(
        label: _tx('admin.stat_avg_latency'),
        value: stats.avgLatencyMs,
        icon: Icons.speed_outlined,
        tint: scheme.secondary,
        unit: 'ms',
      ),
      KpiTile(
        label: stats.topErrorEndpoint ?? _tx('admin.stat_no_errors_today'),
        value: stats.topErrorCount,
        icon: Icons.report_gmailerrorred_outlined,
        tint: _healthColor(context, noErrorsToday),
      ),
    ];

    // None cuando el backend no pudo leer la métrica (p.ej. memoria fuera de
    // Linux, ver _server_health() en admin.py) — se omite la tarjeta en vez
    // de mostrar un "0%" engañoso.
    final serverHealthTiles = <KpiTile>[
      if (stats.diskUsedPct != null)
        KpiTile(
          label: _tx('admin.stat_disk_usage'),
          value: stats.diskUsedPct!.round(),
          icon: Icons.storage_outlined,
          tint: _healthColor(context, stats.diskUsedPct! < 85),
          unit: '%',
          progress: (stats.diskUsedPct! / 100).clamp(0.0, 1.0),
          progressLabel: stats.diskTotalGb == null
              ? null
              : '${stats.diskUsedGb!.toStringAsFixed(1)} / '
                    '${stats.diskTotalGb!.toStringAsFixed(1)} GB',
        ),
      if (stats.memoryUsedPct != null)
        KpiTile(
          label: _tx('admin.stat_memory_usage'),
          value: stats.memoryUsedPct!.round(),
          icon: Icons.memory_outlined,
          tint: _healthColor(context, stats.memoryUsedPct! < 85),
          unit: '%',
          progress: (stats.memoryUsedPct! / 100).clamp(0.0, 1.0),
          progressLabel: stats.memoryTotalGb == null
              ? null
              : '${stats.memoryUsedGb!.toStringAsFixed(1)} / '
                    '${stats.memoryTotalGb!.toStringAsFixed(1)} GB',
        ),
      if (stats.cpuLoadPct != null)
        KpiTile(
          label: _tx('admin.stat_cpu_load'),
          value: stats.cpuLoadPct!.round(),
          icon: Icons.speed_outlined,
          tint: _healthColor(context, stats.cpuLoadPct! < 85),
          unit: '%',
          progress: (stats.cpuLoadPct! / 100).clamp(0.0, 1.0),
          progressLabel: stats.cpuCores == null
              ? null
              : _tx('admin.stat_cpu_cores')
                    .replaceAll('{n}', '${stats.cpuCores}'),
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
                title: _tx('admin.stat_users'),
                value: stats.usersTotal,
                rings: [
                  KpiHeroRing(
                    progress: activePct,
                    label: _tx('admin.stat_active'),
                    color: scheme.primary,
                  ),
                  KpiHeroRing(
                    progress: verifiedPct,
                    label: _tx('admin.stat_verified'),
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
                _tx('admin.stat_section_health'),
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
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
          if (serverHealthTiles.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  _tx('admin.stat_section_server'),
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                minCardWidth: 190,
                itemCount: serverHealthTiles.length,
                itemBuilder: (context, index) => serverHealthTiles[index],
              ),
            ),
          ],
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
  Widget _buildFilterableList<T>({
    required Widget toolbar,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    required String emptyText,
    Future<void> Function()? onRefresh,
    Widget? footer,
  }) {
    return RefreshIndicator(
      onRefresh: onRefresh ?? _load,
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
          if (footer != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverToBoxAdapter(child: footer),
            ),
        ],
      ),
    );
  }
}
