import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/explore/pages/explore_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('public Explore only offers public resource types', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'user-token',
      user: const SessionUser(id: 'user-1', username: 'ada', role: 'user'),
      remember: false,
    );

    String? requestedType;
    List<String> requestedLanguages = const [];
    final client = MockClient((request) async {
      if (request.url.path == '/api/explore') {
        requestedType = request.url.queryParameters['type'];
        requestedLanguages = request.url.queryParametersAll['language'] ?? [];
        return _json([]);
      }
      if (request.url.path == '/api/users') return _json([]);
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppServicesScope(
            apiClient: ApiClient(backend, client: client),
            sessionController: session,
            localeController: locale,
            child: const ExplorePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(requestedType, 'all');
    await tester.tap(find.byKey(const Key('publicExploreTypeDropdown')));
    await tester.pumpAndSettle();

    for (final label in [
      'Agentes (0)',
      'Skills (0)',
      'Prompts (0)',
      'Herramientas (0)',
      'Knowledge (0)',
      'Workflows (0)',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Grupos'), findsNothing);
    expect(find.text('Conexiones'), findsNothing);

    await tester.tap(find.text('Agentes (0)'));
    await tester.pumpAndSettle();
    expect(requestedType, 'agent');

    final filterButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.filter_list),
        matching: find.byType(IconButton),
      ),
    );
    filterButton.onPressed?.call();
    await tester.pumpAndSettle();
    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Español'), findsNothing);

    await tester.tap(find.byKey(const Key('exploreLanguageDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Español'));
    await tester.pumpAndSettle();
    expect(requestedLanguages, ['es']);
  });

  testWidgets(
    'la card oficial es idéntica a la de comunidad salvo la etiqueta',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final backend = await BackendController.bootstrap();
      final locale = await LocaleController.bootstrap();
      final session = await SessionController.bootstrap(
        secureStore: MemorySecureStore(),
      );
      await session.login(
        token: 'user-token',
        user: const SessionUser(id: 'user-1', username: 'ada', role: 'user'),
        remember: false,
      );
      String? linkedPath;
      final client = MockClient((request) async {
        if (request.method == 'POST' && request.url.path.endsWith('/link')) {
          linkedPath = request.url.path;
          return _json({'name': 'Official Analyst'});
        }
        if (request.url.path == '/api/explore') {
          return _json([
            {
              'resource_type': 'agent',
              'resource_id': 'agent-oficial',
              'name': 'Official Analyst',
              'description': 'Analiza fuentes',
              'category': '',
              'labels': ['public', 'official'],
              'owner_username': 'iAgentsHub',
              'stars_count': 3,
            },
            {
              'resource_type': 'agent',
              'resource_id': 'agent-comunidad',
              'name': 'Community Analyst',
              'description': 'También analiza',
              'category': '',
              'labels': ['public', 'community'],
              'owner_username': 'grace',
              'stars_count': 7,
            },
          ]);
        }
        if (request.url.path == '/api/users') return _json([]);
        return _json({}, statusCode: 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppServicesScope(
              apiClient: ApiClient(backend, client: client),
              sessionController: session,
              localeController: locale,
              child: const ExplorePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Official Analyst'), findsOneWidget);
      expect(find.text('Community Analyst'), findsOneWidget);
      // Mismo juego de botones y mismos datos en ambas: propietario, estrella,
      // vista previa, grafo, enlazar. Lo único distinto es el chip de origen.
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.hub_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.link_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.star_border), findsNWidgets(4));
      expect(find.byIcon(Icons.person_outline), findsNWidgets(2));
      expect(find.text('iAgentsHub'), findsOneWidget);
      expect(find.text('grace'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      // Nada de acciones exclusivas del catálogo antiguo.
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      expect(find.byIcon(Icons.download_outlined), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              {'Oficial', 'Official', 'official'}.contains(widget.data),
        ),
        findsOneWidget,
      );

      // Enlazar usa la ruta normal del recurso, no una de catálogo.
      await tester.tap(find.byIcon(Icons.link_outlined).first);
      await tester.pumpAndSettle();
      expect(linkedPath, contains('/api/agents/'));
      expect(linkedPath, isNot(contains('official')));

      for (final width in [768.0, 1024.0, 1440.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'overflow at $width px');
      }
    },
  );

  testWidgets('ofrece grafo solo en agentes, packs y workflows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'user-token',
      user: const SessionUser(id: 'user-1', username: 'ada', role: 'user'),
      remember: false,
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/explore/official-packs') {
        return _json([_pack()]);
      }
      if (request.url.path == '/api/explore') {
        return _json([
          {
            'resource_type': 'agent',
            'resource_id': 'agent-graph',
            'name': 'Agente grafo',
            'owner_username': 'grace',
          },
          {
            'resource_type': 'workflow',
            'resource_id': 'workflow-graph',
            'name': 'Workflow grafo',
            'owner_username': 'grace',
          },
          {
            'resource_type': 'skill',
            'resource_id': 'skill-no-graph',
            'name': 'Skill sin grafo',
            'owner_username': 'grace',
          },
        ]);
      }
      if (request.url.path == '/api/users') return _json([]);
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppServicesScope(
            apiClient: ApiClient(backend, client: client),
            sessionController: session,
            localeController: locale,
            child: const ExplorePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('explore-graph-agent-agent-graph')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('explore-graph-workflow-workflow-graph')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('explore-pack-graph-source-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('explore-graph-skill-skill-no-graph')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('agrupa oficiales por defecto y permite revisar la selección', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'user-token',
      user: const SessionUser(id: 'user-1', username: 'ada', role: 'user'),
      remember: false,
    );
    var communityRequestExcludedOfficial = false;
    final client = MockClient((request) async {
      if (request.url.path == '/api/explore/official-packs/source-1') {
        return _json({
          'pack': _pack(),
          'components': [
            {
              'component_key': 'skill-1',
              'resource_type': 'skill',
              'resource_id': 'official-skill',
              'name': 'Skill del pack',
              'dependencies': [],
              'selectable': true,
              'linked': false,
            },
            {
              'component_key': 'agent-1',
              'resource_type': 'agent',
              'resource_id': 'official-agent',
              'name': 'Agente del pack',
              'dependencies': ['skill-1'],
              'selectable': true,
              'linked': false,
            },
          ],
        });
      }
      if (request.url.path == '/api/explore/official-packs') {
        return _json([_pack()]);
      }
      if (request.url.path == '/api/explore') {
        communityRequestExcludedOfficial =
            request.url.queryParameters['include_official'] == 'false';
        final resources = <Map<String, dynamic>>[
          {
            'resource_type': 'agent',
            'resource_id': 'community-agent',
            'name': 'Agente comunitario',
            'owner_username': 'grace',
            'labels': ['community'],
          },
        ];
        if (!communityRequestExcludedOfficial) {
          resources.add({
            'resource_type': 'agent',
            'resource_id': 'official-agent',
            'name': 'Agente oficial individual',
            'owner_username': 'iAgentsHub',
            'labels': ['official'],
          });
        }
        return _json(resources);
      }
      if (request.url.path == '/api/users') return _json([]);
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppServicesScope(
            apiClient: ApiClient(backend, client: client),
            sessionController: session,
            localeController: locale,
            child: const ExplorePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(communityRequestExcludedOfficial, isTrue);
    expect(find.text('Superpowers'), findsOneWidget);
    expect(find.text('Agente comunitario'), findsOneWidget);
    expect(find.text('Agente del pack'), findsNothing);
    expect(find.byKey(const Key('officialPackModeSelector')), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('Recursos oficiales'), findsOneWidget);
    expect(find.byKey(const Key('officialPackModeSelector')), findsOneWidget);
    await tester.tap(find.text('Individuales'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Superpowers'), findsNothing);
    expect(find.text('Agente oficial individual'), findsOneWidget);
    expect(communityRequestExcludedOfficial, isFalse);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Packs'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Superpowers'), findsOneWidget);
    expect(find.text('Agente oficial individual'), findsNothing);

    await tester.tap(find.byIcon(Icons.visibility_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Skill del pack'), findsOneWidget);
    expect(find.text('Agente del pack'), findsOneWidget);
    expect(find.text('2 seleccionados'), findsOneWidget);

    await tester.tap(
      find.ancestor(
        of: find.text('Skill del pack'),
        matching: find.byType(CheckboxListTile),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0 seleccionados'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final width in [768.0, 1024.0, 1440.0, 1920.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $width px');
    }
  });
}

Map<String, dynamic> _pack() => {
  'item_kind': 'official_pack',
  'source_id': 'source-1',
  'name': 'Superpowers',
  'description': 'Flujo oficial',
  'repository_url': 'https://github.com/obra/superpowers',
  'repository_owner': 'obra',
  'repository_name': 'superpowers',
  'provider': 'github',
  'license': 'MIT',
  'commit_sha': 'abc',
  'counts': {'agent': 1, 'skill': 1},
  'matching_count': 2,
  'total_count': 2,
  'linked_count': 0,
  'link_state': 'none',
};

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
