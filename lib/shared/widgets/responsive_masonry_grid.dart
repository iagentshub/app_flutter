import 'package:flutter/foundation.dart';
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
    this.alignRows = kIsWeb,
    this.minCardWidth,
    this.maxColumns,
    this.crossAxisSpacing = kIsWeb ? 16 : 12,
    this.mainAxisSpacing = kIsWeb ? 16 : 12,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ResponsiveCardDensity density;

  /// Desactivar para tarjetas expandibles que cambian de altura internamente.
  final bool alignRows;
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
        if (alignRows) {
          // Filas alineadas en web, con la altura del contenido más alto.
          // Table mide las celdas sin exigir alturas fijas ni dimensiones
          // intrínsecas a las tarjetas que contienen LayoutBuilder.
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, row) => Padding(
                padding: EdgeInsets.only(top: row == 0 ? 0 : mainAxisSpacing),
                child: Table(
                  defaultVerticalAlignment:
                      TableCellVerticalAlignment.intrinsicHeight,
                  columnWidths: {
                    for (var column = 1; column < columns * 2 - 1; column += 2)
                      column: FixedColumnWidth(crossAxisSpacing),
                  },
                  children: [
                    TableRow(
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          if (column > 0) const SizedBox.shrink(),
                          if (row * columns + column < itemCount)
                            IndexedSemantics(
                              index: row * columns + column,
                              child: itemBuilder(
                                context,
                                row * columns + column,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              childCount: (itemCount / columns).ceil(),
              addSemanticIndexes: false,
            ),
          );
        }
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
