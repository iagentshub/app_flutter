import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/pages/admin_page.dart';
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

  testWidgets('admin synthesizes resources in Explore and opens its graph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1200);
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
      user: const SessionUser(id: 'user-1', username: 'admin', role: 'admin'),
      remember: false,
    );
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/admin/stats') {
        return _json({
          'users_total': 1,
          'users_active': 1,
          'users_verified': 1,
          'connections_total': 0,
          'workflows_total': 0,
          'knowledge_total': 0,
          'conversations_total': 0,
          'agents_public': 0,
          'agents_private': 1,
        });
      }
      if (path == '/api/admin/explore') {
        return _json({
          'items': [
            {
              'resource_type': 'user',
              'id': 'user-1',
              'username': 'admin',
              'email': 'admin@example.com',
              'role': 'admin',
              'is_active': 1,
              'is_verified': 1,
            },
            {
              'resource_type': 'agent',
              'id': 'agent-1',
              'name': 'Researcher',
              'owner_id': 'user-1',
              'owner_username': 'admin',
              'scope': 'private',
            },
            {
              'resource_type': 'group',
              'id': 'group-1',
              'name': 'Platform team',
              'created_by_username': 'admin',
              'status': 'active',
            },
            {
              'resource_type': 'connection',
              'id': 'connection-1',
              'name': 'OpenAI',
              'owner_username': 'admin',
              'type': 'openai',
            },
            {
              'resource_type': 'knowledge',
              'id': 'knowledge-1',
              'title': 'Product guide',
              'owner_username': 'admin',
              'type': 'document',
            },
            {
              'resource_type': 'workflow',
              'id': 'workflow-1',
              'name': 'Release workflow',
              'owner_username': 'admin',
              'steps': 2,
            },
            {
              'resource_type': 'llm_orchestration',
              'id': 'llm-route-1',
              'name': 'Private LLM route',
              'owner_username': 'admin',
              'mode': 'balanced',
              'candidate_count': 3,
            },
          ],
          'total': 7,
          'counts': {
            'user': 1,
            'group': 1,
            'agent': 1,
            'connection': 1,
            'knowledge': 1,
            'workflow': 1,
            'llm_orchestration': 1,
          },
        });
      }
      if (path == '/api/settings/platform') return _json({});
      if (path.endsWith('/graph')) {
        return _json({
          'root_id': 'user:user-1',
          'nodes': [
            {'id': 'user:user-1', 'label': 'admin', 'type': 'user'},
            {'id': 'agent:agent-1', 'label': 'Researcher', 'type': 'agent'},
          ],
          'edges': [
            {
              'source_id': 'user:user-1',
              'target_id': 'agent:agent-1',
              'relation': 'owns',
            },
          ],
        });
      }
      return _json({}, statusCode: 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppServicesScope(
            apiClient: ApiClient(backend, client: client),
            sessionController: session,
            localeController: locale,
            child: const AdminPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Tab), findsNWidgets(4));
    expect(find.text('Explorar'), findsOneWidget);

    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();

    expect(find.text('Todos (7)'), findsOneWidget);
    expect(find.text('Researcher'), findsOneWidget);
    expect(find.text('Platform team'), findsOneWidget);
    expect(find.text('OpenAI'), findsWidgets);
    expect(find.text('Product guide'), findsOneWidget);
    expect(find.text('Release workflow'), findsOneWidget);
    expect(find.text('Private LLM route'), findsOneWidget);
    expect(find.text('Balanceo'), findsOneWidget);
    expect(find.text('3 APIs'), findsOneWidget);
    expect(find.byIcon(Icons.hub_outlined), findsNWidgets(7));

    // Abre el desplegable de tipo, marca solo "Agente" y cierra el menú.
    await tester.tap(find.byKey(const Key('exploreTypeDropdown')));
    await tester.pumpAndSettle();
    expect(find.text('Usuario (1)'), findsWidgets);
    expect(find.text('Agente (1)'), findsWidgets);
    await tester.tap(find.text('Agente (1)').last);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Researcher'), findsOneWidget);
    expect(find.text('admin@example.com'), findsNothing);
    expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);

    // Reabre el desplegable y marca "Todos" para volver a ver todo.
    await tester.tap(find.byKey(const Key('exploreTypeDropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos (7)').last);
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.hub_outlined).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Relaciones de usuario'), findsOneWidget);
    expect(find.text('Researcher'), findsWidgets);
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
