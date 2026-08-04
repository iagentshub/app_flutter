part of '../pages/dashboard_page.dart';

class _FeedBody extends StatefulWidget {
  const _FeedBody({
    super.key,
    required this.token,
    required this.repository,
    required this.exploreRepository,
    required this.config,
    required this.tx,
  });

  final String token;
  final DashboardRepository repository;
  final ExploreRepository exploreRepository;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  State<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends State<_FeedBody> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];
  final Map<String, bool> _starredOverride = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await widget.repository.fetchFeed(
      widget.token,
      types: widget.config.types ?? kFeedTypes,
      limit: widget.config.limit ?? 8,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _toggleStar(Map<String, dynamic> item) async {
    final type = item['resource_type']?.toString() ?? '';
    final id = item['resource_id']?.toString() ?? '';
    final key = '$type:$id';
    final starred = _starredOverride[key] ?? item['starred'] == true;
    try {
      if (starred) {
        await widget.exploreRepository.unstar(
          widget.token,
          resourceType: type,
          resourceId: id,
        );
      } else {
        await widget.exploreRepository.star(
          widget.token,
          resourceType: type,
          resourceId: id,
        );
      }
      if (!mounted) return;
      setState(() => _starredOverride[key] = !starred);
    } catch (_) {
      // ignorar fallo de star silenciosamente
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_items.isEmpty) {
      return Text(
        widget.tx(
          'no_recent_activity',
          'No hay actividad reciente de la comunidad',
        ),
      );
    }

    final defaultResourceName = widget.tx('default_resource_name', 'Recurso');

    return Column(
      children: _items.map((item) {
        final type = item['resource_type']?.toString() ?? '';
        final id = item['resource_id']?.toString() ?? '';
        final key = '$type:$id';
        final starred = _starredOverride[key] ?? item['starred'] == true;
        final name = item['name']?.toString() ?? defaultResourceName;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
          ),
          title: Text(name),
          subtitle: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResourceTypeBadge(
                type: type,
                label: feedTypeLabel(type, widget.tx),
              ),
              if ((item['owner_username']?.toString() ?? '').isNotEmpty) ...[
                const SizedBox(width: 6),
                Text('@${item['owner_username']}'),
              ],
            ],
          ),
          trailing: AppIconButton(
            icon: Icon(
              starred ? Icons.star : Icons.star_border,
              color: starred ? Colors.amber : null,
              size: 20,
            ),
            tooltip: widget.tx(
              'toggle_favorite',
              'Marcar o quitar de favoritos',
            ),
            onPressed: () => _toggleStar(item),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickActionsBody extends StatelessWidget {
  const _QuickActionsBody({required this.config, required this.tx});

  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final definitions = <String, ({IconData icon, String label, String route})>{
      'agent': (
        icon: Icons.smart_toy_outlined,
        label: tx('action_agent', 'Nuevo agente'),
        route: RouteNames.agents,
      ),
      'connection': (
        icon: Icons.cable_outlined,
        label: tx('action_connection', 'Nueva conexión'),
        route: RouteNames.connections,
      ),
      'workflow': (
        icon: Icons.account_tree_outlined,
        label: tx('action_workflow', 'Nuevo workflow'),
        route: RouteNames.orchestrations,
      ),
      'knowledge': (
        icon: Icons.note_add_outlined,
        label: tx('action_knowledge', 'Añadir conocimiento'),
        route: RouteNames.knowledge,
      ),
    };
    final items = config.items ?? kQuickActionItems;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          if (definitions[item] case final action?)
            ActionChip(
              avatar: Icon(action.icon, size: 18),
              label: Text(action.label),
              onPressed: () => context.go(action.route),
            ),
      ],
    );
  }
}

class _TokenKpiBody extends StatelessWidget {
  const _TokenKpiBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final period = config.period ?? '7d';
    final days = switch (period) {
      'today' => 1,
      '30d' => 30,
      _ => 7,
    };
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days - 1));
    final previousStart = start.subtract(Duration(days: days));
    var current = 0;
    var previous = 0;
    final series = <double>[];

    for (final point in data.tokenDaily) {
      final date = DateTime.tryParse(point.day);
      if (date == null) continue;
      if (!date.isBefore(start)) {
        current += point.tokens;
        series.add(point.tokens.toDouble());
      } else if (!date.isBefore(previousStart)) {
        previous += point.tokens;
      }
    }

    final delta = previous == 0
        ? null
        : ((current - previous) / previous * 100);
    final positive = (delta ?? 0) >= 0;
    final periodLabel = switch (period) {
      'today' => tx('period_today', 'Hoy'),
      '30d' => tx('period_30d', 'Últimos 30 días'),
      _ => tx('period_7d', 'Últimos 7 días'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                _formatCompactInt(current),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (delta != null)
              Chip(
                avatar: Icon(
                  positive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                ),
                label: Text('${delta.abs().toStringAsFixed(1)}%'),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
          ],
        ),
        Text(periodLabel, style: Theme.of(context).textTheme.bodySmall),
        if (series.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: series,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final path = Path();

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final normalized = range == 0 ? .5 : (values[index] - minValue) / range;
      final y = size.height - normalized * (size.height - 4) - 2;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
