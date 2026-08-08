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
    await pumpGrid(tester, width: 1600, items: const [compact, full]);

    const column = (1600 - 36) / 4;
    expect(
      tester
          .getSize(find.byKey(const ValueKey('dashboard-slot-compact')))
          .width,
      closeTo(column, 0.01),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('dashboard-slot-full'))).width,
      closeTo(1600, 0.01),
    );
  });
}
