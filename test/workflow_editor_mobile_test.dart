import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/workflows/pages/workflow_editor_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
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

  testWidgets('separa detalles, diagrama e inspector a 360 px', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
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
      token: 'workflow-mobile-token',
      user: const SessionUser(username: 'mobile', role: 'user'),
      remember: false,
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/v2/agents') {
        return _json({
          'items': [
            {'id': 'agent-1', 'name': 'Agente móvil'},
          ],
          'page': {'has_more': false},
        });
      }
      if (request.url.path == '/api/v2/connections') {
        return _json({
          'items': [
            {
              'id': 'llm-orchestration:shared-route',
              'name': 'Ruta LLM del grupo',
              'type': 'llm_orchestration',
              'is_virtual': true,
            },
          ],
          'page': {'has_more': false},
        });
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: WorkflowEditorPage(
          apiClient: ApiClient(backend, client: client),
          sessionController: session,
          localeController: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Detalles'), findsOneWidget);
    expect(find.text('Diagrama'), findsOneWidget);
    expect(find.text('Paso'), findsOneWidget);
    expect(find.byKey(const ValueKey('workflow-save-mobile')), findsOneWidget);
    expect(find.text('Orquestación LLM predeterminada'), findsOneWidget);
    await tester.tap(find.text('Usar la conexión de cada agente'));
    await tester.pumpAndSettle();
    expect(find.text('Ruta LLM del grupo'), findsOneWidget);
    await tester.tap(find.text('Ruta LLM del grupo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Diagrama'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.text('Paso'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(tester.takeException(), isNull);
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
