import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/pages/logs_page.dart';
import 'package:app_flutter/features/admin/repositories/logs_repository.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/models/logs/log_models.dart';
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

  test('decodifica los campos estructurados de auditoría', () {
    const entry = LogEntry(
      raw: {
        'id': 7,
        'category': 'AUDIT',
        'action': 'admin.impersonation.started',
        'resource_type': 'user',
        'resource_id': 'alice',
        'outcome': 'SUCCESS',
        'details_json': '{"reason":"support"}',
      },
    );

    expect(entry.category, 'AUDIT');
    expect(entry.action, 'admin.impersonation.started');
    expect(entry.resourceType, 'user');
    expect(entry.resourceId, 'alice');
    expect(entry.outcome, 'SUCCESS');
    expect(entry.detailsJson, '{"reason":"support"}');
  });

  test('envía todos los filtros estructurados al backend', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    late Uri requestedUrl;
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        requestedUrl = request.url;
        return http.Response(
          jsonEncode({
            'items': <Object>[],
            'total': 0,
            'page': 1,
            'page_size': 50,
            'pages': 0,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    await LogsRepository(apiClient: client).list(
      'token',
      category: 'AUDIT',
      action: 'sharing.revoked',
      resourceType: 'agent',
      resourceId: 'agent-1',
      outcome: 'SUCCESS',
    );

    expect(requestedUrl.queryParameters, containsPair('category', 'AUDIT'));
    expect(
      requestedUrl.queryParameters,
      containsPair('action', 'sharing.revoked'),
    );
    expect(
      requestedUrl.queryParameters,
      containsPair('resource_type', 'agent'),
    );
    expect(
      requestedUrl.queryParameters,
      containsPair('resource_id', 'agent-1'),
    );
    expect(requestedUrl.queryParameters, containsPair('outcome', 'SUCCESS'));
  });

  testWidgets('el visor filtra auditoría sin overflow en móvil', (
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
      token: 'admin-token',
      user: const SessionUser(id: 'admin-1', username: 'admin', role: 'admin'),
      remember: false,
    );
    final requests = <Uri>[];
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        requests.add(request.url);
        if (request.url.path == '/api/admin/logs/summary') {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({
            'items': [
              {
                'id': 1,
                'date': '2026-08-21',
                'time': '12:00:00',
                'ip': '127.0.0.1',
                'username': 'admin',
                'level': 'OK',
                'source': 'BE',
                'summary': 'Impersonación iniciada',
                'category': 'AUDIT',
                'action': 'admin.impersonation.started',
                'resource_type': 'user',
                'resource_id': 'alice',
                'outcome': 'SUCCESS',
                'details_json': '{}',
              },
            ],
            'total': 1,
            'page': 1,
            'page_size': 50,
            'pages': 1,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LogsPageView(
            apiClient: client,
            sessionController: session,
            localeController: locale,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Visor'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Auditoría').first);
    await tester.pumpAndSettle();

    expect(
      requests.any((uri) => uri.queryParameters['category'] == 'AUDIT'),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
