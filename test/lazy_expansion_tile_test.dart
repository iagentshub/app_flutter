import 'package:app_flutter/shared/widgets/lazy_expansion_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// El ExpansionTile de Material construye sus hijos aunque esté cerrado y se
// limita a ocultarlos. Estas pruebas fijan la diferencia: aquí el constructor
// de hijos no llega a ejecutarse hasta que el grupo se abre.

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: ListView(children: [child])),
);

void main() {
  testWidgets('no construye el contenido mientras está cerrado', (
    tester,
  ) async {
    var construcciones = 0;

    await tester.pumpWidget(
      _wrap(
        LazyExpansionTile(
          title: const Text('grupo'),
          childrenBuilder: () {
            construcciones++;
            return const [Text('contenido')];
          },
        ),
      ),
    );

    expect(construcciones, 0);
    expect(find.text('contenido', skipOffstage: false), findsNothing);

    await tester.tap(find.text('grupo'));
    await tester.pumpAndSettle();

    expect(construcciones, greaterThan(0));
    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('initiallyExpanded construye el contenido de entrada', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        LazyExpansionTile(
          title: const Text('grupo'),
          initiallyExpanded: true,
          childrenBuilder: () => const [Text('contenido')],
        ),
      ),
    );

    expect(find.text('contenido'), findsOneWidget);
  });

  testWidgets('al cerrarlo deja de construir el contenido', (tester) async {
    await tester.pumpWidget(
      _wrap(
        LazyExpansionTile(
          title: const Text('grupo'),
          initiallyExpanded: true,
          childrenBuilder: () => const [Text('contenido')],
        ),
      ),
    );

    await tester.tap(find.text('grupo'));
    await tester.pumpAndSettle();

    expect(find.text('contenido', skipOffstage: false), findsNothing);
  });
}
