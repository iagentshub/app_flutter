import 'dart:async';

import 'package:app_flutter/app/router/deferred_page.dart';
import 'package:app_flutter/core/diagnostics/app_diagnostics.dart';
import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/widgets/async_state_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

/// [DeferredPage] es lo único que separa «la parte tarda» de «la sección está
/// rota»: si la descarga falla, la ruta se queda en blanco hasta recargar la
/// pestaña entera. Aquí se prueban los tres caminos — carga, fallo con
/// reintento, y segunda visita sin parpadeo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(DeferredPage.forgetLoadedForTest);
  tearDown(DeferredPage.forgetLoadedForTest);

  testWidgets('muestra el indicador de carga hasta que llega la parte', (
    tester,
  ) async {
    final parte = Completer<void>();
    await _pump(tester, name: 'demo', loader: () => parte.future);

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Página cargada'), findsNothing);

    parte.complete();
    await tester.pumpAndSettle();

    expect(find.text('Página cargada'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('un fallo de red deja reintentar la descarga', (tester) async {
    // El fallo se registra a propósito en los diagnósticos; sin silenciar el
    // reporter, ese registro tumbaría el propio test.
    AppDiagnostics.setReporter((_) {});
    addTearDown(AppDiagnostics.resetReporter);

    var intentos = 0;
    await _pump(
      tester,
      name: 'demo',
      loader: () async {
        intentos++;
        if (intentos == 1) throw StateError('sin red');
      },
    );
    await tester.pumpAndSettle();

    expect(find.byType(AsyncStatePanel), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Página cargada'), findsNothing);

    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();

    expect(intentos, 2);
    expect(find.text('Página cargada'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('la segunda visita monta la página en el primer frame', (
    tester,
  ) async {
    var cargas = 0;
    await _pump(
      tester,
      name: 'demo',
      loader: () async {
        cargas++;
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Página cargada'), findsOneWidget);

    // Salir y volver: `loadLibrary()` ya está cacheado, pero sin el registro
    // de partes cargadas el FutureBuilder pintaría igualmente un frame de
    // espera en cada entrada a la sección.
    await _pump(
      tester,
      name: 'demo',
      loader: () async {
        cargas++;
      },
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Página cargada'), findsOneWidget);
    expect(cargas, 1);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required String name,
  required DeferredLibraryLoader loader,
}) async {
  SharedPreferences.setMockInitialValues({});
  final backend = await BackendController.bootstrap();
  final locale = await LocaleController.bootstrap();
  final session = await SessionController.bootstrap(
    secureStore: MemorySecureStore(),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppServicesScope(
          apiClient: ApiClient(backend),
          sessionController: session,
          localeController: locale,
          child: DeferredPage(
            name: name,
            loader: loader,
            builder: (context) => const Text('Página cargada'),
          ),
        ),
      ),
    ),
  );
}
