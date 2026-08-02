part of '../pages/dashboard_page.dart';

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{
      'agents': data.agents.length,
      'connections': data.connections.length,
      'skills': data.skills.length,
      'memory': data.memory.length,
      'knowledge': data.knowledge.length,
      'workflows': data.workflows.length,
    };
    final routes = <String, String>{
      'agents': RouteNames.agents,
      'connections': RouteNames.connections,
      'skills': RouteNames.knowledge,
      'memory': RouteNames.knowledge,
      'knowledge': RouteNames.knowledge,
      'workflows': RouteNames.orchestrations,
    };
    final icons = <String, IconData>{
      'agents': Icons.smart_toy_outlined,
      'connections': Icons.cable_outlined,
      'skills': Icons.auto_awesome_outlined,
      'memory': Icons.description_outlined,
      'knowledge': Icons.menu_book_outlined,
      'workflows': Icons.account_tree_outlined,
    };
    // Agrupadas por afinidad (construcción / integraciones / contenido) con
    // el mismo criterio de 3 bloques de color que las KPI de Admin → General,
    // en vez de un icono monocromo igual para las 6.
    final scheme = Theme.of(context).colorScheme;
    final tints = <String, Color>{
      'agents': scheme.primary,
      'workflows': scheme.primary,
      'connections': scheme.secondary,
      'skills': scheme.secondary,
      'memory': scheme.tertiary,
      'knowledge': scheme.tertiary,
    };
    final items = config.items ?? kSummaryItems;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 90,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return KpiRowTile(
          label: summaryItemLabel(item, tx),
          value: counts[item] ?? 0,
          icon: icons[item] ?? Icons.circle_outlined,
          tint: tints[item] ?? scheme.primary,
          onTap: () => context.go(routes[item] ?? RouteNames.dashboard),
        );
      },
    );
  }
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final days = config.days ?? 14;
    final all = data.tokenDaily;
    final daily = all.length > days ? all.sublist(all.length - days) : all;
    final total = daily.fold<int>(0, (sum, item) => sum + item.tokens);
    final max = daily.fold<int>(
      0,
      (m, item) => item.tokens > m ? item.tokens : m,
    );

    if (daily.isEmpty) {
      return Text(tx('no_activity', 'Sin actividad todavía'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx(
            'total_tokens_days',
            'Total: {{total}} tokens ({{days}} días)',
          ).replaceAll('{{total}}', '$total').replaceAll('{{days}}', '$days'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: daily.map((point) {
              final ratio = max > 0 ? point.tokens / max : 0.0;
              return Expanded(
                child: Tooltip(
                  message: '${point.day}: ${point.tokens} tokens',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: FractionallySizedBox(
                      heightFactor: ratio.clamp(0.03, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              daily.first.day,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(daily.last.day, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _TokenUsageBody extends StatelessWidget {
  const _TokenUsageBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final groupBy = config.groupBy ?? 'connection';
    final scope = config.scope ?? 'all';
    final limit = config.limit ?? 5;

    final personalConnectionIds = data.connections
        .where((c) => c['_personal_key'] == true || c['scope'] == 'personal')
        .map((c) => c['id']?.toString() ?? '')
        .toSet();

    final defaultAgentName = tx('default_agent_name', 'Agente');
    final defaultConnectionName = tx('default_connection_name', 'Conexión');

    List<MapEntry<String, int>> rows;
    if (groupBy == 'agent') {
      final agents = data.agents.where((a) {
        if (scope != 'personal') return true;
        final connId = a['connection_id']?.toString();
        return connId == null ||
            connId.isEmpty ||
            personalConnectionIds.contains(connId);
      });
      rows =
          agents
              .map((a) {
                final tokensIn = (a['tokens_in'] as num?)?.toInt() ?? 0;
                final tokensOut = (a['tokens_out'] as num?)?.toInt() ?? 0;
                final name = a['name']?.toString() ?? defaultAgentName;
                return MapEntry(name, tokensIn + tokensOut);
              })
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
    } else {
      final connections = scope == 'personal'
          ? data.connections.where(
              (c) => personalConnectionIds.contains(c['id']),
            )
          : data.connections;
      rows =
          connections
              .map((c) {
                final tokensIn = (c['tokens_in'] as num?)?.toInt() ?? 0;
                final tokensOut = (c['tokens_out'] as num?)?.toInt() ?? 0;
                final name =
                    c['name']?.toString() ??
                    c['type']?.toString() ??
                    defaultConnectionName;
                return MapEntry(name, tokensIn + tokensOut);
              })
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
    }
    rows = rows.take(limit).toList();
    final max = rows.isEmpty ? 1 : rows.first.value;

    if (rows.isEmpty) {
      return Text(tx('no_token_usage', 'Todavía no hay consumo de tokens'));
    }
    return Column(
      children: rows.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${entry.value}'),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: entry.value / max,
                  minHeight: 6,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
