import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/shared/widgets/buttons/resource_create_button.dart';
import 'package:app_flutter/shared/widgets/resource_collection_view.dart';
import 'package:app_flutter/shared/widgets/resource_toolbar.dart';
import 'package:app_flutter/shared/widgets/responsive_masonry_grid.dart';
import 'package:app_flutter/shared/widgets/web_content_frame.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('redimensionar conserva el texto y el foco de búsqueda', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceToolbar(
            title: 'Tus agentes',
            description: 'Crea, organiza y ejecuta tus asistentes de IA.',
            primaryAction: ResourceCreateButton(
              onPressed: () {},
              label: 'Crear agente',
            ),
            search: TextField(focusNode: focus),
            actions: const [Text('Acciones')],
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'Asistente de soporte');
    expect(focus.hasFocus, isTrue);
    tester.view.physicalSize = const Size(600, 900);
    await tester.pump();
    expect(find.text('Asistente de soporte'), findsOneWidget);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  Future<void> mount(
    WidgetTester tester,
    Widget child, {
    double width = 1200,
    double scale = 1,
    bool dark = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 900),
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('barra local: acciones accesibles con zoom y distintos anchos', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    var created = 0;
    for (final width in [320.0, 600.0, 900.0, 1200.0, 1920.0]) {
      for (final scale in [1.0, 2.0]) {
        await mount(
          tester,
          WebContentFrame(
            child: ResourceCollectionView(
              header: ResourceToolbar(
                title: 'Tus agentes',
                description: 'Crea, organiza y ejecuta tus asistentes de IA.',
                primaryAction: ResourceCreateButton(
                  onPressed: () => created++,
                  label: 'Crear agente',
                ),
                search: const TextField(
                  key: Key('search'),
                  decoration: InputDecoration(labelText: 'Buscar agente'),
                ),
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Actualizar',
                  ),
                  const ActionChip(
                    label: Text('Grupo activo con un nombre largo'),
                  ),
                ],
                summary: const Text('Agentes: 128'),
              ),
              itemCount: 0,
              empty: const Text('Sin resultados'),
              itemBuilder: (_, index) => Text('$index'),
            ),
          ),
          width: width,
          scale: scale,
          dark: scale == 1,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '$width px, texto x$scale',
        );
        final action = find.byType(ResourceCreateButton);
        final rect = tester.getRect(action);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        await tester.tap(action);
        await tester.pump();
      }
    }
    expect(created, 10);
  });

  testWidgets('búsqueda en línea solo en web; móvil conserva el apilado', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(
      tester,
      const Padding(
        padding: EdgeInsets.all(16),
        child: ResourceToolbar(
          search: SizedBox(key: Key('search'), height: 40, child: TextField()),
          actions: [SizedBox(key: Key('action'), height: 40, width: 40)],
        ),
      ),
    );
    final search = tester.getRect(find.byKey(const Key('search')));
    final action = tester.getRect(find.byKey(const Key('action')));
    if (kIsWeb) {
      expect(search.center.dy, action.center.dy);
      expect(search.left, greaterThan(action.right));
    } else {
      expect(search.top, greaterThan(action.bottom));
    }
  });

  testWidgets(
    'tarjetas web alineadas por filas, sin fijar su altura ni crear toda la colección',
    (tester) async {
      addTearDown(tester.view.reset);
      final built = <int>{};
      await mount(
        tester,
        CustomScrollView(
          slivers: [
            ResponsiveSliverMasonryGrid(
              itemCount: 500,
              itemBuilder: (context, index) {
                built.add(index);
                return Container(
                  key: ValueKey('card-$index'),
                  constraints: BoxConstraints(minHeight: index == 1 ? 180 : 80),
                  child: Text('Tarjeta $index'),
                );
              },
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
      expect(built.length, lessThan(100));
      if (kIsWeb) {
        final first = tester.getRect(find.byKey(const ValueKey('card-0')));
        final second = tester.getRect(find.byKey(const ValueKey('card-1')));
        final nextRow = tester.getRect(find.byKey(const ValueKey('card-3')));
        expect(first.top, second.top);
        expect(first.bottom, second.bottom);
        expect(nextRow.top, greaterThan(first.bottom));
      }
    },
  );

  testWidgets(
    'marco web limita monitores grandes y deja el ancho nativo intacto',
    (tester) async {
      addTearDown(tester.view.reset);
      await mount(
        tester,
        const WebContentFrame(child: SizedBox.expand(key: Key('content'))),
        width: 2400,
      );
      final rect = tester.getRect(find.byKey(const Key('content')));
      expect(rect.width, kIsWeb ? 1584 : 2400);
      expect(rect.center.dx, 1200);
    },
  );

  testWidgets('menú expandido no se comprime durante la animación web', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    await mount(
      tester,
      const SizedBox(
        width: 72,
        child: ClipRect(
          child: WebSidebarViewport(
            width: 240,
            child: SizedBox.expand(key: Key('menu')),
          ),
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('menu'))).width,
      kIsWeb ? 240 : 72,
    );
    expect(tester.takeException(), isNull);
  });
}
