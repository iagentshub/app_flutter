import 'package:app_flutter/shared/widgets/explore_search_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shares a descriptive type selector and adapts to mobile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var selected = <String>{};
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ExploreSearchToolbar(
              searchController: searchController,
              searchHint: 'Buscar recursos por nombre, autor o descripción',
              typeOptions: const [
                ExploreTypeOption(
                  value: 'agent',
                  label: 'Agentes',
                  icon: Icons.smart_toy_outlined,
                  color: Colors.red,
                ),
                ExploreTypeOption(
                  value: 'skill',
                  label: 'Skills',
                  icon: Icons.bolt_outlined,
                  color: Colors.blue,
                ),
              ],
              selectedTypes: selected,
              allTypesLabel: 'Todos',
              typeFilterTooltip: 'Filtrar recursos por tipo',
              multipleTypesLabel: (count) => '$count tipos',
              allowMultipleTypes: false,
              selectorKey: const Key('typeSelector'),
              onTypesChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.text('Buscar recursos por nombre, autor o descripción'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('typeSelector')));
    await tester.pumpAndSettle();
    expect(find.text('Agentes'), findsOneWidget);
    expect(find.text('Skills'), findsOneWidget);

    await tester.tap(find.text('Agentes'));
    await tester.pumpAndSettle();
    expect(selected, {'agent'});
  });

  testWidgets('keeps multiple admin selections while the menu stays open', (
    tester,
  ) async {
    var selected = <String>{};
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ExploreSearchToolbar(
              searchController: searchController,
              searchHint: 'Buscar',
              typeOptions: const [
                ExploreTypeOption(
                  value: 'user',
                  label: 'Usuarios',
                  icon: Icons.person_outline,
                  color: Colors.blue,
                ),
                ExploreTypeOption(
                  value: 'agent',
                  label: 'Agentes',
                  icon: Icons.smart_toy_outlined,
                  color: Colors.red,
                ),
              ],
              selectedTypes: selected,
              allTypesLabel: 'Todos',
              typeFilterTooltip: 'Filtrar',
              multipleTypesLabel: (count) => '$count tipos',
              selectorKey: const Key('adminTypeSelector'),
              onTypesChanged: (next) => setState(() => selected = next),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('adminTypeSelector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuarios'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agentes'));
    await tester.pumpAndSettle();

    expect(selected, {'user', 'agent'});
  });
}
