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
    final client = MockClient((request) async {
      if (request.url.path == '/api/explore') {
        requestedType = request.url.queryParameters['type'];
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
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
