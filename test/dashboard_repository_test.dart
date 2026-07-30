import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/dashboard/repositories/dashboard_repository.dart';
import 'package:app_flutter/models/dashboard/dashboard_widget_instance.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
  });

  test('lee layouts v2 con varias instancias del mismo tipo', () async {
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('dashboard-layout-v2')) {
        return http.Response(
          jsonEncode({
            'version': 2,
            'items': [
              {
                'id': 'kpi-a',
                'type': 'token-kpi',
                'size': 'compact',
                'config': {'period': '7d'},
              },
              {
                'id': 'kpi-b',
                'type': 'token-kpi',
                'size': 'medium',
                'config': {'period': '30d'},
              },
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    final preferences = await DashboardRepository(
      client,
    ).getPreferences('token');

    expect(preferences.isVersioned, isTrue);
    expect(preferences.instances.map((item) => item.id), ['kpi-a', 'kpi-b']);
    expect(preferences.instances.last.size, DashboardWidgetSize.medium);
  });

  test('carga únicamente los endpoints requeridos por los widgets', () async {
    final paths = <String>[];
    final mock = MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path == '/api/connections/tokens-daily') {
        return http.Response('[{"day":"2026-07-30","tokens":42}]', 200);
      }
      if (request.url.path == '/api/chats/recent') {
        return http.Response('[{"id":"conversation-a"}]', 200);
      }
      return http.Response('[]', 200);
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    final data = await DashboardRepository(client).fetchData(
      gaToken: 'token',
      sources: {
        DashboardDataSource.tokenDaily,
        DashboardDataSource.conversations,
      },
    );

    expect(paths, ['/api/connections/tokens-daily', '/api/chats/recent']);
    expect(data.tokenDaily.single.tokens, 42);
    expect(data.conversations.single['id'], 'conversation-a');
    expect(data.agents, isEmpty);
  });
}
