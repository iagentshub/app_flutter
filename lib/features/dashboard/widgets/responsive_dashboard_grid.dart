import 'package:flutter/material.dart';

import '../../../models/dashboard/dashboard_widget_instance.dart';

/// Rejilla del dashboard: reparte las tarjetas en filas de `columns` huecos
/// según el tamaño de cada una.
///
/// Cada fila es una `Table` de una sola fila, y no un `Wrap`, por dos cosas
/// que se veían al añadir todos los widgets:
///
/// - **Las tarjetas de una misma fila miden lo mismo.** Con `Wrap` cada una
///   media su propio contenido y las bajas dejaban un hueco debajo hasta la
///   siguiente fila, con la rejilla escalonada.
///   `TableCellVerticalAlignment.intrinsicHeight` mide y vuelve a maquetar con
///   la altura de la más alta **sin preguntar dimensiones intrínsecas**, que es
///   lo que descarta `IntrinsicHeight`: hay cuerpos con `GridView` y con
///   `LayoutBuilder`, y ninguno sabe responderlas.
/// - **La fila ocupa el ancho completo.** Cuando el siguiente widget no cabe,
///   lo que sobra se reparte entre las tarjetas de la fila en proporción a su
///   tamaño, en vez de quedar como un hueco al final.
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
        final columns =
            ((constraints.maxWidth + spacing) / (minColumnWidth + spacing))
                .floor()
                .clamp(1, maxColumns);
        final columnWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final rows = _packRows(columns);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var row = 0; row < rows.length; row++) ...[
              if (row > 0) SizedBox(height: spacing),
              _buildRow(
                context,
                rows[row],
                columns,
                columnWidth,
                constraints.maxWidth,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRow(
    BuildContext context,
    List<int> row,
    int columns,
    double columnWidth,
    double rowWidth,
  ) {
    final spans = [
      for (final index in row) _spanFor(items[index].size, columns),
    ];
    final used = spans.reduce((a, b) => a + b);
    // Huecos que la fila no llegó a llenar, repartidos por tamaño de tarjeta.
    final leftover = (columnWidth + spacing) * (columns - used);
    var remaining = rowWidth - spacing * (row.length - 1);

    final widths = <int, TableColumnWidth>{};
    final cells = <Widget>[];
    for (var slot = 0; slot < row.length; slot++) {
      final index = row[slot];
      if (cells.isNotEmpty) {
        widths[cells.length] = FixedColumnWidth(spacing);
        cells.add(const SizedBox());
      }
      // La última se lleva lo que queda: sumar anchos calculados uno a uno
      // deja un residuo de coma flotante y la fila desborda por milésimas.
      final width = slot == row.length - 1
          ? remaining
          : columnWidth * spans[slot] +
                spacing * (spans[slot] - 1) +
                leftover * spans[slot] / used;
      remaining -= width;
      widths[cells.length] = FixedColumnWidth(width);
      cells.add(
        KeyedSubtree(
          key: ValueKey('dashboard-slot-${items[index].id}'),
          child: itemBuilder(context, items[index], index),
        ),
      );
    }
    return Table(
      columnWidths: widths,
      defaultVerticalAlignment: TableCellVerticalAlignment.intrinsicHeight,
      children: [TableRow(children: cells)],
    );
  }

  /// Reparto por orden: la tarjeta entra en la fila en curso si le quedan
  /// huecos. No se adelanta una posterior más pequeña para tapar el sobrante
  /// porque el orden lo decide el usuario en modo edición.
  List<List<int>> _packRows(int columns) {
    final rows = <List<int>>[];
    var current = <int>[];
    var used = 0;
    for (var index = 0; index < items.length; index++) {
      final span = _spanFor(items[index].size, columns);
      if (current.isNotEmpty && used + span > columns) {
        rows.add(current);
        current = [];
        used = 0;
      }
      current.add(index);
      used += span;
    }
    if (current.isNotEmpty) rows.add(current);
    return rows;
  }

  int _spanFor(DashboardWidgetSize size, int columns) {
    final requested = switch (size) {
      DashboardWidgetSize.compact => 1,
      DashboardWidgetSize.medium => 2,
      DashboardWidgetSize.wide => 3,
      DashboardWidgetSize.full => columns,
    };
    return requested.clamp(1, columns);
  }
}
