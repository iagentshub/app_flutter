import 'package:app_flutter/shared/widgets/motion/app_route_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// El `child` que un ShellRoute entrega a su layout **es el Navigator del
/// shell**, y ese Navigator lleva `GlobalKey` (`router.dart`). Envolverlo en
/// algo que mantenga viva la vista saliente junto a la entrante —un
/// `PageTransitionSwitcher`, un `AnimatedSwitcher`— pone el mismo Navigator en
/// dos ramas del árbol a la vez.
///
/// En debug eso es «Duplicate GlobalKey detected in widget tree». En release no
/// hay aserción: Flutter arranca el elemento de una rama, lo re-adopta en la
/// otra, y **la pantalla se queda sin pintar hasta que otro evento programa un
/// frame**. Se vivió como «las vistas tardan segundos en aparecer, y no salen
/// hasta que abro el menú».
///
/// Por eso la transición entre secciones la hacen las páginas del router
/// (`fadeThroughPage` en `internal_router.dart`), dentro del Navigator, y el
/// shell entrega su `child` tal cual.
void main() {
  testWidgets('cambiar de sección pinta el contenido sin ayuda', (
    tester,
  ) async {
    final shellKey = GlobalKey<NavigatorState>();
    final router = GoRouter(
      initialLocation: '/uno',
      routes: [
        ShellRoute(
          navigatorKey: shellKey,
          // Igual que AppShell: el child se entrega sin envolver.
          builder: (context, state, child) => Scaffold(
            body: Column(children: [Expanded(child: child)]),
          ),
          routes: [
            GoRoute(
              path: '/uno',
              pageBuilder: (context, state) =>
                  fadeThroughPage(key: state.pageKey, child: const Text('UNO')),
            ),
            GoRoute(
              path: '/dos',
              pageBuilder: (context, state) =>
                  fadeThroughPage(key: state.pageKey, child: const Text('DOS')),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('UNO'), findsOneWidget);

    router.go('/dos');
    await tester.pumpAndSettle();

    // Sin bombear nada más ni forzar un rebuild: el contenido tiene que estar.
    expect(
      find.text('DOS'),
      findsOneWidget,
      reason:
          'La sección nueva no se pintó. Si alguien volvió a envolver el child '
          'del ShellRoute en un switcher, este es el síntoma.',
    );
    expect(find.text('UNO'), findsNothing);
  });
}
