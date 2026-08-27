import 'package:app_flutter/features/dashboard/widgets/responsive_dashboard_grid.dart';
import 'package:app_flutter/models/dashboard/dashboard_widget_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const compact = DashboardWidgetInstance(
    id: 'compact',
    type: 'token-kpi',
    size: DashboardWidgetSize.compact,
  );
  const medium = DashboardWidgetInstance(
    id: 'medium',
    type: 'recent',
    size: DashboardWidgetSize.medium,
  );
  DashboardWidgetInstance compactWithId(String id) => DashboardWidgetInstance(
    id: id,
    type: 'token-kpi',
    size: DashboardWidgetSize.compact,
  );
  const full = DashboardWidgetInstance(
    id: 'full',
    type: 'summary',
    size: DashboardWidgetSize.full,
  );

  Future<void> pumpGrid(
    WidgetTester tester, {
    required double width,
    List<DashboardWidgetInstance> items = const [compact, medium, full],
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: ResponsiveDashboardGrid(
                items: items,
                itemBuilder: (_, instance, _) =>
                    SizedBox(height: instance.id == 'compact' ? 80 : 140),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('usa una columna sin overflow en móvil', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpGrid(tester, width: 360);

    for (final id in ['compact', 'medium', 'full']) {
      expect(
        tester.getSize(find.byKey(ValueKey('dashboard-slot-$id'))).width,
        closeTo(360, 0.01),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('crece a tres columnas y respeta spans', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpGrid(tester, width: 800);

    const column = (800 - 24) / 3;
    expect(
      tester
          .getSize(find.byKey(const ValueKey('dashboard-slot-compact')))
          .width,
      closeTo(column, 0.01),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('dashboard-slot-medium'))).width,
      closeTo(column * 2 + 12, 0.01),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('dashboard-slot-full'))).width,
      closeTo(800, 0.01),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('limita el ultrawide a cuatro columnas', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpGrid(
      tester,
      width: 1600,
      items: [for (var i = 0; i < 4; i++) compactWithId('c$i'), full],
    );

    const column = (1600 - 36) / 4;
    for (var i = 0; i < 4; i++) {
      expect(
        tester.getSize(find.byKey(ValueKey('dashboard-slot-c$i'))).width,
        closeTo(column, 0.01),
      );
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('dashboard-slot-full'))).width,
      closeTo(1600, 0.01),
    );
  });

  testWidgets('iguala la altura de las tarjetas de una misma fila', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpGrid(tester, width: 800);

    expect(
      tester
          .getSize(find.byKey(const ValueKey('dashboard-slot-compact')))
          .height,
      closeTo(140, 0.01),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('dashboard-slot-medium')))
          .height,
      closeTo(140, 0.01),
    );
  });

  testWidgets('admite cuerpos con GridView y LayoutBuilder', (tester) async {
    // El motivo de que la fila iguale alturas con Table y no con
    // IntrinsicHeight: estos dos no saben responder dimensiones intrínsecas y
    // los cuerpos reales del dashboard los llevan.
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveDashboardGrid(
            items: const [compact, medium],
            itemBuilder: (_, instance, _) => instance.id == 'compact'
                ? GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    children: const [SizedBox(), SizedBox()],
                  )
                : LayoutBuilder(
                    builder: (_, _) => const SizedBox(height: 200),
                  ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('dashboard-slot-compact')))
          .height,
      tester.getSize(find.byKey(const ValueKey('dashboard-slot-medium'))).height,
    );
  });

  testWidgets('reparte el sobrante en vez de dejar un hueco al final', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // medium(2) + compact(1) llenan la fila de 3; el segundo medium no cabe y
    // se queda solo, ocupando el ancho entero.
    await pumpGrid(
      tester,
      width: 800,
      items: const [
        medium,
        compact,
        DashboardWidgetInstance(
          id: 'medium-2',
          type: 'recent',
          size: DashboardWidgetSize.medium,
        ),
      ],
    );

    expect(
      tester.getSize(find.byKey(const ValueKey('dashboard-slot-medium-2'))).width,
      closeTo(800, 0.01),
    );
  });
}
