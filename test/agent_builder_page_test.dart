import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/core/storage/secure_store.dart';
import 'package:app_flutter/features/agents/pages/agent_builder_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('recupera texto y conexiones tras un 404 del constructor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: _MemorySecureStore(),
    );
    await session.login(
      token: 'user-token',
      user: const SessionUser(username: 'member', role: 'user'),
      remember: false,
    );

    var connectionRequests = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path == '/api/connections') {
        connectionRequests += 1;
        return _json(
          connectionRequests == 1
              ? [
                  {
                    'id': 'stale-connection',
                    'name': 'Conexión antigua',
                    'type': 'openai',
                    'model': 'modelo-antiguo',
                  },
                ]
              : [
                  {
                    'id': 'available-connection',
                    'name': 'Conexión disponible',
                    'type': 'openai',
                    'model': 'modelo-disponible',
                  },
                ],
        );
      }
      if (request.url.path == '/api/skills' ||
          request.url.path == '/api/knowledge') {
        return _json([]);
      }
      if (request.url.path == '/api/agent-builder/chat') {
        return _json({
          'detail': {
            'code': 'not_found',
            'message':
                'La conexión seleccionada no existe o no está disponible',
          },
        }, statusCode: 404);
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AgentBuilderPage(
          apiClient: ApiClient(backend, client: httpClient),
          sessionController: session,
          localeController: locale,
        ),
      ),
    );
    await tester.pumpAndSettle();

    const prompt = 'Crea un agente de soporte para mi equipo';
    await tester.enterText(
      find.byKey(const ValueKey('agent-builder-composer')),
      prompt,
    );
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    expect(connectionRequests, 2);
    expect(
      find.text('La conexión seleccionada no existe o no está disponible'),
      findsOneWidget,
    );
    expect(
      find.text('Conexión disponible · modelo-disponible'),
      findsOneWidget,
    );
    expect(find.text('Conexión antigua · modelo-antiguo'), findsNothing);
    final composer = tester.widget<TextField>(
      find.byKey(const ValueKey('agent-builder-composer')),
    );
    expect(composer.controller?.text, prompt);
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

class _MemorySecureStore implements SecureStore {
  final _values = <String, String>{};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}
