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

  testWidgets('la card oficial es idéntica a la de comunidad salvo la etiqueta', (
    tester,
  ) async {
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
    // Mismo juego de botones y mismos datos en ambas: propietario, favoritos,
    // vista previa, enlazar. Lo único distinto es el chip de origen.
    expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.link_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.bookmark_outline), findsNWidgets(4));
    expect(find.byIcon(Icons.person_outline), findsNWidgets(2));
    expect(find.text('iAgentsHub'), findsOneWidget);
    expect(find.text('grace'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    // Nada de acciones exclusivas del catálogo antiguo.
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsNothing);
    expect(find.byIcon(Icons.hub_outlined), findsNothing);
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
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
