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

  testWidgets('official resources are individual cards without visible ids', (
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
    String? linkedPath;
    Map<String, dynamic>? linkedBody;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/official-packages/package-private-id') {
        return _json({
          'id': 'package-private-id',
          'name': 'Research Pack',
          'version': {
            'components': [
              {
                'component_id': 'agent-private-id',
                'component_type': 'agent',
                'name': 'Official Analyst',
                'source_path': 'agents/analyst.md',
                'dependencies': ['skill-private-id'],
              },
              {
                'component_id': 'skill-private-id',
                'component_type': 'skill',
                'name': 'Research Skill',
                'source_path': 'skills/research/SKILL.md',
                'dependencies': [],
              },
              {
                'component_id': 'knowledge-private-id',
                'component_type': 'knowledge',
                'name': 'Research Notes',
                'source_path': 'knowledge/notes.md',
                'dependencies': [],
              },
            ],
          },
        });
      }
      if (request.method == 'POST' &&
          request.url.path ==
              '/api/official-packages/package-private-id/link') {
        linkedPath = request.url.path;
        linkedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'name': 'Official Analyst'});
      }
      if (request.url.path == '/api/explore') {
        return _json([
          {
            'resource_type': 'agent',
            'resource_id': 'package-private-id:agent-private-id',
            'name': 'Official Analyst',
            'description': 'Analiza fuentes',
            'category': '',
            'labels': ['official', 'lang_es'],
            'owner_username': 'iAgentsHub',
            'is_official': true,
            'hub_installable': true,
            'official_package_id': 'package-private-id',
            'official_package_name': 'Research Pack',
            'official_component_id': 'agent-private-id',
            'official_version': 'v1',
            'direct_dependency_ids': ['skill-private-id'],
            'dependencies': [
              {
                'component_id': 'skill-private-id',
                'name': 'Research Skill',
                'component_type': 'skill',
                'dependencies': [],
              },
            ],
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
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            {'Oficial', 'Official', 'official'}.contains(widget.data),
      ),
      findsOneWidget,
    );
    expect(find.text('Otros'), findsNothing);
    expect(find.text('Producción'), findsNothing);
    expect(find.text('Research Pack'), findsOneWidget);
    expect(find.textContaining('private-id'), findsNothing);
    // La etiqueta "official" ya marca el origen: la card no repite la estrella.
    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.bookmark_outline), findsNothing);
    expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
    expect(find.byIcon(Icons.link_outlined), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
    expect(find.text('Oficiales'), findsNothing);

    await tester.tap(find.byIcon(Icons.link_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Elegir contenido de la fuente'), findsOneWidget);
    expect(find.textContaining('private-id'), findsNothing);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Research Notes'));
    await tester.pump();
    await tester.tap(find.text('Usar selección'));
    await tester.pumpAndSettle();
    expect(linkedPath, '/api/official-packages/package-private-id/link');
    expect((linkedBody?['component_ids'] as List).toSet(), {
      'agent-private-id',
      'skill-private-id',
      'knowledge-private-id',
    });
    expect(find.byIcon(Icons.link), findsOneWidget);

    for (final width in [768.0, 1024.0, 1440.0, 1920.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'overflow at $width px');
    }
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
