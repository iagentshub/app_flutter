import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/executions/controllers/resource_executions_controller.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'tipa y reconoce el estado canónico por cualquiera de sus ids',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = await BackendController.bootstrap();
      final session = await SessionController.bootstrap(
        secureStore: MemorySecureStore(),
      );
      await session.login(
        token: 'token',
        user: const SessionUser(username: 'alice', role: 'user'),
        remember: false,
      );
      var requests = 0;
      final client = ApiClient(
        backend,
        client: MockClient((request) async {
          requests += 1;
          return http.Response(
            jsonEncode([
              {
                'execution_id': 'exec-1',
                'resource_type': 'agent',
                'resource_id': 'public-agent',
                'resource_ids': ['public-agent', 'local-copy'],
                'status': 'in_progress',
                'started_at': '2026-01-01T00:00:00Z',
              },
            ]),
            200,
          );
        }),
      );
      final controller = ResourceExecutionsController(
        apiClient: client,
        sessionController: session,
        pollInterval: const Duration(hours: 1),
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);

      await _waitUntil(() => controller.isInProgress('agent', 'local-copy'));
      expect(requests, 1);
      expect(controller.executions.single.id, 'exec-1');
      expect(controller.isInProgress('agent', 'public-agent'), isTrue);
      expect(controller.isInProgress('workflow', 'local-copy'), isFalse);
    },
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('La condición no se cumplió a tiempo');
}
