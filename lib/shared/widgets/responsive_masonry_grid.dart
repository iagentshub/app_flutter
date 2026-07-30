import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

enum ResponsiveCardDensity {
  detailed(minCardWidth: 340, maxColumns: 8),
  compact(minCardWidth: 220, maxColumns: 10),
  marketing(minCardWidth: 300, maxColumns: 8);

  const ResponsiveCardDensity({
    required this.minCardWidth,
    required this.maxColumns,
  });

  final double minCardWidth;
  final int maxColumns;
}

class ResponsiveSliverMasonryGrid extends StatelessWidget {
  const ResponsiveSliverMasonryGrid({
    required this.itemCount,
    required this.itemBuilder,
    this.density = ResponsiveCardDensity.detailed,
    this.minCardWidth,
    this.maxColumns,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 12,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ResponsiveCardDensity density;
  final double? minCardWidth;
  final int? maxColumns;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  @visibleForTesting
  static int crossAxisCountForWidth({
    required double availableWidth,
    required double minCardWidth,
    required double spacing,
    required int maxColumns,
  }) {
    if (!availableWidth.isFinite || availableWidth <= 0) return 1;
    return ((availableWidth + spacing) / (minCardWidth + spacing))
        .floor()
        .clamp(1, maxColumns);
  }

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = crossAxisCountForWidth(
          availableWidth: constraints.crossAxisExtent,
          minCardWidth: minCardWidth ?? density.minCardWidth,
          spacing: crossAxisSpacing,
          maxColumns: maxColumns ?? density.maxColumns,
        );
        return SliverMasonryGrid.count(
          crossAxisCount: columns,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}
