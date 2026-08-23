import 'package:animations/animations.dart';
import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/shared/widgets/motion/app_modal.dart';
import 'package:app_flutter/shared/widgets/motion/app_motion.dart';
import 'package:app_flutter/shared/widgets/motion/app_page_transitions.dart';
import 'package:app_flutter/shared/widgets/motion/app_route_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Activa el ajuste de movimiento reducido del sistema para el test en curso.
void _conMovimientoReducido(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('relleno de las transiciones', () {
    // El `fillColor` por defecto de FadeThroughTransition es `canvasColor`, y
    // en el tema claro ese es blanco puro (#FFFFFF) mientras el fondo real de
    // las páginas es `scaffoldBackgroundColor` (#F5F5F7). La diferencia se veía
    // como un fogonazo blanco a mitad de la transición de login a configurar
    // backend, en los dos sentidos.
    test('el tema claro tiene un canvasColor que no sirve de relleno', () {
      final claro = AppTheme.light('light-red');
      expect(
        claro.canvasColor,
        isNot(claro.scaffoldBackgroundColor),
        reason:
            'Si dejan de diferir, este test sobra — pero mientras difieran, '
            'ninguna transición puede rellenar con el canvasColor.',
      );
    });

    testWidgets('la transición entre rutas rellena con el fondo real', (
      tester,
    ) async {
      final tema = AppTheme.light('light-red');
      final router = GoRouter(
        initialLocation: '/uno',
        routes: [
          GoRoute(
            path: '/uno',
            pageBuilder: (context, state) => fadeThroughPage(
              key: state.pageKey,
              child: const Scaffold(body: Text('uno')),
            ),
          ),
          GoRoute(
            path: '/dos',
            pageBuilder: (context, state) => fadeThroughPage(
              key: state.pageKey,
              child: const Scaffold(body: Text('dos')),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(theme: tema, routerConfig: router),
      );
      router.go('/dos');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      final rellenos = tester
          .widgetList<FadeThroughTransition>(find.byType(FadeThroughTransition))
          .map((t) => t.fillColor)
          .toSet();

      expect(
        rellenos,
        isNotEmpty,
        reason: 'La transición no llegó a montarse.',
      );
      expect(
        rellenos,
        everyElement(equals(tema.scaffoldBackgroundColor)),
        reason:
            'Rellenar con otra cosa que el fondo de las páginas es el fogonazo '
            'blanco que se veía al ir de login a configurar backend.',
      );
    });
  });

  group('showAppDialog', () {
    testWidgets('abre el diálogo y devuelve lo que se le pasa al cerrar', (
      tester,
    ) async {
      String? resultado;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await showAppDialog<String>(
                    context: context,
                    builder: (context) => AlertDialog(
                      content: TextButton(
                        onPressed: () => Navigator.of(context).pop('elegido'),
                        child: const Text('Elegir'),
                      ),
                    ),
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Elegir'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(resultado, 'elegido');
    });

    testWidgets('con movimiento reducido el diálogo no escala', (tester) async {
      _conMovimientoReducido(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showAppDialog<void>(
                  context: context,
                  builder: (context) =>
                      const AlertDialog(content: Text('Hola')),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(FadeScaleTransition), findsNothing);
    });
  });

  group('transiciones de página', () {
    testWidgets('con movimiento reducido la página entra sin transición', (
      tester,
    ) async {
      _conMovimientoReducido(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(pageTransitionsTheme: appPageTransitionsTheme),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Detalle')),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Detalle'), findsOneWidget);
      expect(find.byType(SharedAxisTransition), findsNothing);
    });

    test('los dos temas de la app declaran la transición de página', () {
      for (final tema in [
        AppTheme.light('dark-red'),
        AppTheme.dark('dark-red'),
      ]) {
        expect(
          tema.pageTransitionsTheme.builders[TargetPlatform.android],
          isA<AppPageTransitionsBuilder>(),
          reason: 'una página abierta con push no debe entrar de golpe',
        );
      }
    });
  });

  group('AppMotion', () {
    testWidgets('refleja el ajuste del sistema', (tester) async {
      late bool reducido;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              reducido = AppMotion.reduced(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(reducido, isFalse);

      _conMovimientoReducido(tester);
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              reducido = AppMotion.reduced(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(reducido, isTrue);
    });
  });
}
