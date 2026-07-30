import 'package:app_flutter/shared/widgets/responsive_masonry_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calcula columnas sin crear cards por debajo del ancho mínimo', () {
    expect(
      ResponsiveSliverMasonryGrid.crossAxisCountForWidth(
        availableWidth: 339,
        minCardWidth: 340,
        spacing: 12,
        maxColumns: 8,
      ),
      1,
    );
    expect(
      ResponsiveSliverMasonryGrid.crossAxisCountForWidth(
        availableWidth: 692,
        minCardWidth: 340,
        spacing: 12,
        maxColumns: 8,
      ),
      2,
    );
    expect(
      ResponsiveSliverMasonryGrid.crossAxisCountForWidth(
        availableWidth: 1044,
        minCardWidth: 340,
        spacing: 12,
        maxColumns: 8,
      ),
      3,
    );
    expect(
      ResponsiveSliverMasonryGrid.crossAxisCountForWidth(
        availableWidth: 5000,
        minCardWidth: 340,
        spacing: 12,
        maxColumns: 8,
      ),
      8,
    );
  });

  testWidgets('se renderiza en una columna móvil y varias en escritorio', (
    tester,
  ) async {
    Future<void> pumpAtWidth(double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: ResponsiveSliverMasonryGrid(
                  itemCount: 4,
                  itemBuilder: (context, index) => SizedBox(
                    key: ValueKey('card-$index'),
                    height: 80.0 + (index * 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpAtWidth(400);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('card-0'))).dx,
      tester.getTopLeft(find.byKey(const ValueKey('card-1'))).dx,
    );

    await pumpAtWidth(800);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('card-0'))).dx,
      isNot(tester.getTopLeft(find.byKey(const ValueKey('card-1'))).dx),
    );
  });

  testWidgets('admite colecciones vacías, unitarias y grandes sin overflow', (
    tester,
  ) async {
    Future<void> pumpItems(int itemCount) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CustomScrollView(
            slivers: [
              ResponsiveSliverMasonryGrid(
                itemCount: itemCount,
                itemBuilder: (context, index) => Card(
                  key: ValueKey('item-$index'),
                  child: SizedBox(height: 60.0 + (index % 4) * 20),
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await pumpItems(0);
    expect(find.byType(Card), findsNothing);

    await pumpItems(1);
    expect(find.byKey(const ValueKey('item-0')), findsOneWidget);

    await pumpItems(50);
    expect(find.byKey(const ValueKey('item-0')), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
  });
}
