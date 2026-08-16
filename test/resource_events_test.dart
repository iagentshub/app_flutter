import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/resource_events.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/watches_resource_changes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

// Cada pantalla recargaba por su cuenta después de mutar, así que la que hacía
// el cambio se enteraba y las demás seguían enseñando su copia. Aquí se fija lo
// contrario: quien muta no avisa a nadie —lo hace el cliente HTTP— y quien
// pinta declara qué mira.

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ResourceEvents', () {
    test('deriva el tipo de recurso de la ruta', () {
      expect(ResourceEvents.typeFromPath('/api/agents'), 'agents');
      expect(
        ResourceEvents.typeFromPath('/api/agents/private/ag-1'),
        'agents',
      );
      expect(
        ResourceEvents.typeFromPath('/api/knowledge?limit=50'),
        'knowledge',
      );
      expect(ResourceEvents.typeFromPath('/api'), '');
      expect(ResourceEvents.typeFromPath(''), '');
    });

    test('agrupa los avisos de un mismo ciclo en una notificación', () async {
      final events = ResourceEvents();
      var notificaciones = 0;
      final vistos = <String>{};
      events.addListener(() {
        notificaciones++;
        vistos.addAll(events.pending);
      });

      events.changed('agents');
      events.changed('skills');
      events.changed('agents');
      await Future<void>.delayed(Duration.zero);

      expect(notificaciones, 1, reason: 'una acción, una recarga');
      expect(vistos, {'agents', 'skills'});
    });

    test('no notifica sin cambios', () async {
      final events = ResourceEvents();
      var notificaciones = 0;
      events.addListener(() => notificaciones++);

      events.changed('');
      await Future<void>.delayed(Duration.zero);

      expect(notificaciones, 0);
    });
  });

  // Estos dos no son pruebas de interfaz: el reloj falso de `testWidgets`
  // deja colgada cualquier petición con timeout.
  test('una mutación avisa del recurso que tocó', () async {
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(
      await BackendController.bootstrap(),
      client: MockClient((_) async => http.Response('{}', 200)),
    );
    final avisos = <Set<String>>[];
    client.resourceEvents.addListener(
      () => avisos.add(client.resourceEvents.pending),
    );

    await client.post('/api/agents', body: const {'name': 'x'});
    await Future<void>.delayed(Duration.zero);

    expect(avisos, [
      {'agents'},
    ]);
  });

  test('un GET no avisa de nada', () async {
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(
      await BackendController.bootstrap(),
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    var avisos = 0;
    client.resourceEvents.addListener(() => avisos++);

    await client.get('/api/agents');
    await Future<void>.delayed(Duration.zero);

    expect(avisos, 0);
  });

  testWidgets('la vista que mira un recurso recarga cuando otra lo cambia', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    final client = ApiClient(
      backend,
      client: MockClient((_) async {
        return http.Response(jsonEncode(const []), 200, headers: {
          'content-type': 'application/json',
        });
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppServicesScope(
            apiClient: client,
            sessionController: session,
            localeController: locale,
            child: const _VistaEspia(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final estado = tester.state<_VistaEspiaState>(find.byType(_VistaEspia));
    final recargasIniciales = estado.recargas;

    // Otra pantalla cualquiera cambia un agente.
    await client.post('/api/agents', body: const {'name': 'nuevo'});
    await tester.pumpAndSettle();

    expect(estado.recargas, recargasIniciales + 1);

    // Un recurso que esta vista no mira no la despierta.
    await client.post('/api/connections', body: const {'name': 'otra cosa'});
    await tester.pumpAndSettle();

    expect(estado.recargas, recargasIniciales + 1);
  });
}

class _VistaEspia extends StatefulWidget {
  const _VistaEspia();

  @override
  State<_VistaEspia> createState() => _VistaEspiaState();
}

class _VistaEspiaState extends State<_VistaEspia> with WatchesResourceChanges {
  int recargas = 0;

  @override
  Set<String> get watchedResources => const {'agents'};

  @override
  Future<void> onResourcesChanged(Set<String> changed) async => recargas++;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
