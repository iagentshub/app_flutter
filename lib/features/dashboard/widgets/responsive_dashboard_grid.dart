import 'package:flutter/material.dart';

import '../../../models/dashboard/dashboard_widget_instance.dart';

class ResponsiveDashboardGrid extends StatelessWidget {
  const ResponsiveDashboardGrid({
    required this.items,
    required this.itemBuilder,
    this.minColumnWidth = 240,
    this.maxColumns = 4,
    this.spacing = 12,
    super.key,
  });

  final List<DashboardWidgetInstance> items;
  final Widget Function(
    BuildContext context,
    DashboardWidgetInstance instance,
    int index,
  )
  itemBuilder;
  final double minColumnWidth;
  final int maxColumns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final columns =
            ((availableWidth + spacing) / (minColumnWidth + spacing))
                .floor()
                .clamp(1, maxColumns);
        final columnWidth =
            (availableWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var index = 0; index < items.length; index++)
              SizedBox(
                key: ValueKey('dashboard-slot-${items[index].id}'),
                width: _widthFor(items[index].size, columns, columnWidth),
                child: itemBuilder(context, items[index], index),
              ),
          ],
        );
      },
    );
  }

  double _widthFor(DashboardWidgetSize size, int columns, double columnWidth) {
    final requestedSpan = switch (size) {
      DashboardWidgetSize.compact => 1,
      DashboardWidgetSize.medium => 2,
      DashboardWidgetSize.wide => 3,
      DashboardWidgetSize.full => columns,
    };
    final span = requestedSpan.clamp(1, columns);
    return columnWidth * span + spacing * (span - 1);
  }
}
