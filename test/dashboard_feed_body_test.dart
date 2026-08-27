import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/dashboard/cards/dashboard_feed_body.dart';
import 'package:app_flutter/features/dashboard/repositories/dashboard_repository.dart';
import 'package:app_flutter/features/explore/repositories/explore_repository.dart';
import 'package:app_flutter/models/dashboard/dashboard_widget_config.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/i18n_de_prueba.dart';

void main() {
  setUp(cargarTraduccionesDePrueba);

  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
  });

  testWidgets('muestra el error del feed y permite reintentar', (tester) async {
    var attempts = 0;
    final client = ApiClient(
      backendController,
      client: MockClient((request) async {
        expect(request.url.path, '/api/feed');
        attempts++;
        return attempts == 1
            ? http.Response('fallo', 503)
            : http.Response('[]', 200);
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();

    expect(find.text("No se pudo cargar la actividad"), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);

    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(
      find.text('No hay actividad reciente de la comunidad'),
      findsOneWidget,
    );
  });

  testWidgets('hace visible el fallo al actualizar la estrella', (tester) async {
    final client = ApiClient(
      backendController,
      client: MockClient((request) async {
        if (request.url.path == '/api/feed') {
          return http.Response(
            jsonEncode([
              {
                'resource_type': 'agent',
                'resource_id': 'agent-1',
                'name': 'Agente de prueba',
                'starred': false,
              },
            ]),
            200,
          );
        }
        if (request.url.path == '/api/agent/agent-1/star') {
          return http.Response('fallo', 503);
        }
        return http.Response('no encontrado', 404);
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(_app(client));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Poner o quitar la estrella'));
    await tester.pump();

    expect(find.text('No se pudo actualizar la estrella'), findsOneWidget);
    expect(find.text('Agente de prueba'), findsOneWidget);
  });
}

Widget _app(ApiClient client) {
  return MaterialApp(
    home: Scaffold(
      body: DashboardFeedBody(
        token: 'token',
        repository: DashboardRepository(client),
        exploreRepository: ExploreRepository(apiClient: client),
        config: const DashboardWidgetConfig(),
        // Igual que DashboardPage: la clave del widget cuelga de `dashboard.`
        tx: (clave) => trOr('dashboard.$clave', clave),
      ),
    ),
  );
}
