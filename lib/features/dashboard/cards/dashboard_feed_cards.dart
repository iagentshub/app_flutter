import 'package:flutter/material.dart';

import '../../../app/router/internal_router.dart';
import '../../../app/router/router.dart';
import '../../../models/dashboard/dashboard_data.dart';
import '../../../models/dashboard/dashboard_widget_config.dart';
import '../dashboard_formatters.dart';

class DashboardQuickActionsBody extends StatelessWidget {
  const DashboardQuickActionsBody({
    required this.config,
    required this.tx,
    super.key,
  });

  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final definitions = <String, ({IconData icon, String label, String route})>{
      'agent': (
        icon: Icons.smart_toy_outlined,
        label: tx('action_agent', 'Nuevo agente'),
        route: InternalRoutes.agents,
      ),
      'connection': (
        icon: Icons.cable_outlined,
        label: tx('action_connection', 'Nueva conexión'),
        route: InternalRoutes.connections,
      ),
      'workflow': (
        icon: Icons.account_tree_outlined,
        label: tx('action_workflow', 'Nuevo workflow'),
        route: InternalRoutes.orchestrations,
      ),
      'knowledge': (
        icon: Icons.note_add_outlined,
        label: tx('action_knowledge', 'Añadir conocimiento'),
        route: InternalRoutes.knowledge,
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
              onPressed: () => AppRouter.go(context, action.route),
            ),
      ],
    );
  }
}

class DashboardTokenKpiBody extends StatelessWidget {
  const DashboardTokenKpiBody({
    required this.data,
    required this.config,
    required this.tx,
    super.key,
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
                formatCompactDashboardInt(current),
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
