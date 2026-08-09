import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/widgets/official_packages_admin_tab.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('edita cards sin mostrar ids y sincroniza la selección', (
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
    Map<String, dynamic>? publishedBody;
    final syncedPaths = <String>[];
    final packages = [
      {
        'id': 'hidden-package-a',
        'name': 'Package Alpha',
        'description': 'Alpha description',
        'repository_url': 'https://github.com/example/alpha',
        'tracking_mode': 'release',
        'tracking_ref': 'main',
        'license': 'MIT',
        'versions': <Object>[
          {
            'version': 'v2',
            'status': 'pending_review',
            'validation_errors': <Object>[],
            'components': <Object>[
              {
                'component_id': 'agent-hidden-id',
                'component_type': 'agent',
                'name': 'Official Agent',
                'source_path': 'agents/official.md',
                'dependencies': ['skill-hidden-id'],
              },
              {
                'component_id': 'skill-hidden-id',
                'component_type': 'skill',
                'name': 'Official Skill',
                'source_path': 'skills/official/SKILL.md',
                'dependencies': <Object>[],
              },
              {
                'component_id': 'knowledge-hidden-id',
                'component_type': 'knowledge',
                'name': 'Optional Knowledge',
                'source_path': 'knowledge/optional.md',
                'dependencies': <Object>[],
              },
            ],
          },
        ],
      },
      {
        'id': 'hidden-package-b',
        'name': 'Package Beta',
        'description': 'Beta description',
        'repository_url': 'https://github.com/example/beta',
        'tracking_mode': 'branch',
        'tracking_ref': 'stable',
        'license': 'Apache-2.0',
        'versions': <Object>[],
      },
    ];
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/admin/official-packages') {
        return _json(packages);
      }
      if (request.method == 'PUT') {
        editedPath = request.url.path;
        editedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json(editedBody!);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/sync')) {
        syncedPaths.add(request.url.path);
        return _json({});
      }
      if (request.method == 'POST' && request.url.path.endsWith('/publish')) {
        publishedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({});
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficialPackagesAdminTab(
            apiClient: ApiClient(backend, client: client),
            token: 'admin-token',
            tx: (_, fallback) => fallback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Package Alpha'), findsOneWidget);
    expect(find.text('Package Beta'), findsOneWidget);
    expect(find.text('hidden-package-a'), findsNothing);
    expect(find.text('hidden-package-b'), findsNothing);
    // La card se queda en título + url + acciones: ni versión ni estado.
    expect(find.text('https://github.com/example/alpha'), findsOneWidget);
    expect(find.textContaining('pending_review'), findsNothing);
    expect(find.textContaining('v2'), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Alpha edited');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(editedPath, '/api/admin/official-packages/hidden-package-a');
    expect(editedBody?['name'], 'Alpha edited');
    expect(editedBody?.containsKey('id'), isFalse);

    await tester.tap(find.byTooltip('Sincronizar esta fuente').first);
    await tester.pumpAndSettle();
    expect(syncedPaths, ['/api/admin/official-packages/hidden-package-a/sync']);
    syncedPaths.clear();

    await tester.tap(find.text('Sincronizar'));
    await tester.pumpAndSettle();
    expect(find.text('Elegir paquetes para sincronizar'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Package Beta'));
    await tester.pump();
    await tester.tap(find.text('Sincronizar seleccionados'));
    await tester.pumpAndSettle();

    expect(syncedPaths, ['/api/admin/official-packages/hidden-package-a/sync']);

    await tester.tap(find.byIcon(Icons.publish));
    await tester.pumpAndSettle();
    expect(find.text('Elegir contenido a publicar'), findsOneWidget);
    expect(find.textContaining('hidden-id'), findsNothing);
    // La ruta distingue componentes que se llaman igual.
    expect(find.text('skills/official/SKILL.md'), findsOneWidget);
    expect(find.text('knowledge/optional.md'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Optional Knowledge'),
    );
    await tester.pump();
    await tester.tap(find.text('Publicar selección'));
    await tester.pumpAndSettle();
    expect((publishedBody?['component_ids'] as List).toSet(), {
      'agent-hidden-id',
      'skill-hidden-id',
    });
  });

  testWidgets('sincronizar pregunta qué publicar y reeditar parte de lo ya '
      'publicado', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final publishedBodies = <Map<String, dynamic>>[];
    final components = <Object>[
      {
        'component_id': 'kept-skill',
        'component_type': 'skill',
        'name': 'Kept Skill',
        'dependencies': <Object>[],
      },
      {
        'component_id': 'dropped-knowledge',
        'component_type': 'knowledge',
        'name': 'Dropped Knowledge',
        'dependencies': <Object>[],
      },
    ];
    final packages = [
      {
        'id': 'package-a',
        'name': 'Package Alpha',
        'repository_url': 'https://github.com/example/alpha',
        'tracking_mode': 'release',
        'tracking_ref': 'main',
        'license': 'MIT',
        'published_version': 'v1',
        'versions': <Object>[
          {
            'version': 'v1',
            'status': 'published',
            'validation_errors': <Object>[],
            'published_components': ['kept-skill'],
            'components': components,
          },
        ],
      },
    ];
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/admin/official-packages') {
        return _json(packages);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/sync')) {
        return _json({
          'changed': true,
          'package': packages.first,
          'version': {
            'version': 'v2',
            'status': 'pending_review',
            'validation_errors': <Object>[],
            'published_components': <Object>[],
            'components': components,
          },
        });
      }
      if (request.method == 'POST' && request.url.path.endsWith('/publish')) {
        publishedBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _json({});
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfficialPackagesAdminTab(
            apiClient: ApiClient(backend, client: client),
            token: 'admin-token',
            tx: (_, fallback) => fallback,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sincronizar la fuente abre el selector con todo marcado y publica.
    await tester.tap(find.byTooltip('Sincronizar esta fuente').first);
    await tester.pumpAndSettle();
    expect(find.text('Elegir contenido a publicar'), findsOneWidget);
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Dropped Knowledge'),
    );
    await tester.pump();
    await tester.tap(find.text('Publicar selección'));
    await tester.pumpAndSettle();
    expect((publishedBodies.last['component_ids'] as List), ['kept-skill']);

    // Reeditar la selección publicada arranca solo con lo que está publicado.
    await tester.tap(find.byTooltip('Elegir contenido publicado').first);
    await tester.pumpAndSettle();
    final dropped = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Dropped Knowledge'),
    );
    final kept = tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, 'Kept Skill'),
    );
    expect(dropped.value, isFalse);
    expect(kept.value, isTrue);
    await tester.tap(
      find.widgetWithText(CheckboxListTile, 'Dropped Knowledge'),
    );
    await tester.pump();
    await tester.tap(find.text('Publicar selección'));
    await tester.pumpAndSettle();
    expect((publishedBodies.last['component_ids'] as List).toSet(), {
      'kept-skill',
      'dropped-knowledge',
    });
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
