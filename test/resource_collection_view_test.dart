import 'package:app_flutter/shared/widgets/resource_collection_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Diez pantallas repetían este esqueleto a mano y habían divergido entre
// copias. Estas pruebas fijan lo que todas deben cumplir ahora.

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('construye solo las tarjetas visibles', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final construidas = <int>[];
    await tester.pumpWidget(
      _wrap(
        ResourceCollectionView(
          itemCount: 500,
          itemBuilder: (context, index) {
            construidas.add(index);
            return SizedBox(height: 100, child: Text('tarjeta $index'));
          },
        ),
      ),
    );

    expect(construidas, isNotEmpty);
    expect(
      construidas.length,
      lessThan(100),
      reason: 'con 500 elementos no puede construirlos todos: $construidas',
    );
  });

  testWidgets('enseña el estado vacío en vez de la rejilla', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ResourceCollectionView(
          itemCount: 0,
          empty: const Text('sin nada'),
          itemBuilder: (context, index) => const Text('no debería'),
        ),
      ),
    );

    expect(find.text('sin nada'), findsOneWidget);
    expect(find.text('no debería'), findsNothing);
  });

  testWidgets('una colección vacía se sigue pudiendo refrescar', (
    tester,
  ) async {
    // Varias copias perdían el gesto justo cuando no había nada que enseñar,
    // que es cuando el usuario más quiere reintentar.
    var refrescos = 0;
    await tester.pumpWidget(
      _wrap(
        ResourceCollectionView(
          itemCount: 0,
          empty: const Text('sin nada'),
          onRefresh: () async => refrescos++,
          itemBuilder: (context, index) => const SizedBox.shrink(),
        ),
      ),
    );

    await tester.fling(find.text('sin nada'), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(refrescos, 1);
  });

  testWidgets('pide más páginas al acercarse al final', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var peticiones = 0;
    await tester.pumpWidget(
      _wrap(
        ResourceCollectionView(
          itemCount: 30,
          hasMore: true,
          onLoadMore: () async => peticiones++,
          itemBuilder: (context, index) =>
              SizedBox(height: 100, child: Text('tarjeta $index')),
        ),
      ),
    );

    expect(peticiones, 0, reason: 'sin scroll no debe pedir nada todavía');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pump();

    expect(peticiones, greaterThan(0));
  });

  testWidgets('sin hasMore no pide más aunque se llegue al final', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var peticiones = 0;
    await tester.pumpWidget(
      _wrap(
        ResourceCollectionView(
          itemCount: 30,
          onLoadMore: () async => peticiones++,
          itemBuilder: (context, index) =>
              SizedBox(height: 100, child: Text('tarjeta $index')),
        ),
      ),
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2500));
    await tester.pump();

    expect(peticiones, 0);
  });
}
