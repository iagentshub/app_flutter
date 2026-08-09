import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/workflows/controllers/workflow_runs_controller.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

Map<String, dynamic> _run({
  String id = 'run-1',
  String name = 'Informe',
  String status = 'running',
}) => {
  'id': id,
  'workflow_id': 'workflow-1',
  'workflow_name': name,
  'status': status,
  'definition': {
    'nodes': [
      {'id': 'one', 'agent_id': 'agent-1'},
    ],
    'edges': <Object>[],
  },
  'agents': [
    {'id': 'agent-1', 'name': 'Analista'},
  ],
  'progress': {'completed': status == 'completed' ? 1 : 0, 'total': 1},
  'last_sequence': status == 'completed' ? 2 : 0,
  'created_at': '2026-01-01T00:00:00Z',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('inicia, reproduce eventos y actualiza el historial', () async {
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

    final requests = <String>[];
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}');
        if (request.method == 'POST' && request.url.path.endsWith('/runs')) {
          return http.Response(jsonEncode(_run()), 202);
        }
        if (request.url.path.endsWith('/events')) {
          return http.Response(
            'data: ${jsonEncode({'type': 'stage_done', 'node_id': 'one', 'sequence': 1})}\n\n'
            'data: ${jsonEncode({'type': 'workflow_done', 'output': 'ok', 'sequence': 2})}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }
        if (request.url.path == '/api/workflow-runs/run-1') {
          return http.Response(jsonEncode(_run(status: 'completed')), 200);
        }
        return http.Response('[]', 200);
      }),
    );
    final controller = WorkflowRunsController(
      apiClient: client,
      sessionController: session,
      autoStart: false,
    );
    addTearDown(controller.dispose);
    addTearDown(client.close);

    final started = await controller.startRun(
      workflowId: 'workflow-1',
      input: 'datos',
    );
    final events = await controller.events(started.id).toList();

    expect(controller.activeCount, 0);
    expect(events.map((event) => event['sequence']), [1, 2]);
    expect(requests, contains('POST /api/workflows/workflow-1/runs'));
    expect(requests, contains('GET /api/workflow-runs/run-1/events'));
  });

  test(
    'descarta una respuesta en vuelo después de cambiar de cuenta',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = await BackendController.bootstrap();
      final session = await SessionController.bootstrap(
        secureStore: MemorySecureStore(),
      );
      await session.login(
        token: 'alice-token',
        user: const SessionUser(username: 'alice', role: 'user'),
        remember: false,
      );

      final aliceResponse = Completer<http.Response>();
      var requestCount = 0;
      final client = ApiClient(
        backend,
        client: MockClient((request) {
          requestCount += 1;
          if (requestCount == 1) return aliceResponse.future;
          return Future.value(
            http.Response(
              jsonEncode([_run(id: 'bob-run', name: 'Privado de Bob')]),
              200,
            ),
          );
        }),
      );
      final controller = WorkflowRunsController(
        apiClient: client,
        sessionController: session,
      );
      addTearDown(controller.dispose);
      addTearDown(client.close);

      final publishedNames = <String>[];
      controller.addListener(() {
        publishedNames.addAll(controller.runs.map((run) => run.workflowName));
      });
      await _waitUntil(() => controller.loading);

      await session.login(
        token: 'bob-token',
        user: const SessionUser(username: 'bob', role: 'user'),
        remember: false,
      );
      aliceResponse.complete(
        http.Response(
          jsonEncode([_run(id: 'alice-run', name: 'Privado de Alice')]),
          200,
        ),
      );

      await _waitUntil(
        () =>
            controller.runs.any((run) => run.workflowName == 'Privado de Bob'),
      );
      expect(session.user?.username, 'bob');
      expect(publishedNames, isNot(contains('Privado de Alice')));
      expect(controller.runs.single.workflowName, 'Privado de Bob');
    },
  );

  test('reduce el polling cuando no hay ejecuciones activas', () async {
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

    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(jsonEncode(_run()), 202);
        }
        return http.Response('[]', 200);
      }),
    );
    final controller = WorkflowRunsController(
      apiClient: client,
      sessionController: session,
    );
    addTearDown(controller.dispose);
    addTearDown(client.close);

    await _waitUntil(
      () => controller.debugNextPollDelay == const Duration(minutes: 1),
    );
    await controller.startRun(workflowId: 'workflow-1', input: 'datos');

    expect(controller.activeCount, 1);
    expect(controller.debugNextPollDelay, const Duration(seconds: 5));
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  fail('La condición no se cumplió a tiempo');
}
