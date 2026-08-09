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

Map<String, dynamic> _run({String status = 'running'}) => {
  'id': 'run-1',
  'workflow_id': 'workflow-1',
  'workflow_name': 'Informe',
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
}
