import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/widgets/official_sources_admin_tab.dart';
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

  final components = <Object>[
    {
      'component_id': 'kept-skill',
      'component_type': 'skill',
      'name': 'Kept Skill',
      'source_path': 'skills/kept/SKILL.md',
      'dependencies': <Object>[],
      'materializable': true,
    },
    {
      'component_id': 'dropped-knowledge',
      'component_type': 'knowledge',
      'name': 'Dropped Knowledge',
      'source_path': 'knowledge/dropped.md',
      'dependencies': <Object>[],
      'materializable': true,
    },
  ];

  final sources = [
    {
      'id': 'source-a',
      'name': 'Source Alpha',
      'repository_url': 'https://github.com/example/alpha',
      'tracking_mode': 'release',
      'tracking_ref': 'main',
      'license': 'MIT',
      'resources': [
        {
          'resource_type': 'skill',
          'resource_id': 'skill-1',
          'component_id': 'kept-skill',
        },
      ],
    },
  ];

  testWidgets('la card muestra la fuente sin ids y permite editarla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    String? editedPath;
    Map<String, dynamic>? editedBody;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/admin/official-sources') {
        return _json(sources);
      }
      if (request.method == 'PUT') {
        editedPath = request.url.path;
        editedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(editedBody!);
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(_tab(backend, client));
    await tester.pumpAndSettle();

    expect(find.text('Source Alpha'), findsOneWidget);
    expect(find.text('https://github.com/example/alpha'), findsOneWidget);
    expect(find.text('1 objetos en el hub'), findsOneWidget);
    expect(find.text('source-a'), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Alpha edited');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(editedPath, '/api/admin/official-sources/source-a');
    expect(editedBody?['name'], 'Alpha edited');
  });

  testWidgets('sincronizar elige qué se queda y desmarcar lo borra', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final syncBodies = <String?>[];
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/admin/official-sources') {
        return _json(sources);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/sync')) {
        syncBodies.add(request.body.isEmpty ? null : request.body);
        return _json({
          'source': sources.first,
          'version': 'v1',
          'components': components,
          // Lo que ya está en el hub: preselecciona la skill, no el knowledge.
          'selected': ['kept-skill'],
          'errors': <Object>[],
          'security_warnings': <Object>[],
          'applied': {'resources': <Object>[], 'removed': 1},
        });
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(_tab(backend, client));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sincronizar y elegir contenido').first);
    await tester.pumpAndSettle();

    expect(find.text('Elegir contenido de la fuente'), findsOneWidget);
    expect(find.text('skills/kept/SKILL.md'), findsOneWidget);
    final kept = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Kept Skill'),
    );
    final dropped = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Dropped Knowledge'),
    );
    expect(kept.value, isTrue);
    expect(dropped.value, isFalse);

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Kept Skill'));
    await tester.pump();
    await tester.tap(find.text('Aplicar selección'));
    await tester.pumpAndSettle();

    // Primera llamada sin cuerpo (mirar), segunda con la selección vacía.
    expect(syncBodies.first, isNull);
    expect(jsonDecode(syncBodies.last!)['component_ids'], isEmpty);
  });

  testWidgets('el diálogo de importación cabe en móvil', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final client = MockClient((request) async {
      if (request.url.path == '/api/admin/official-sources' ||
          request.url.path == '/api/admin/connections') {
        return _json([]);
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(_tab(backend, client));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Añadir fuente oficial'));
    await tester.pumpAndSettle();

    expect(find.text('Importar desde GitHub o GitLab'), findsOneWidget);
    expect(find.text('Modo de análisis'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Widget _tab(BackendController backend, http.Client client) {
  return MaterialApp(
    home: Scaffold(
      body: OfficialSourcesAdminTab(
        apiClient: ApiClient(backend, client: client),
        token: 'admin-token',
        tx: tr,
      ),
    ),
  );
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
