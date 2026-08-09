import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/workflows/pages/workflows_page.dart';
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

  for (final width in [360.0, 768.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('shows agent and LLM API tabs at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
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
      final client = MockClient((request) async {
        if (request.url.path == '/api/workflows' ||
            request.url.path == '/api/agents') {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppServicesScope(
              apiClient: ApiClient(backend, client: client),
              sessionController: session,
              localeController: locale,
              child: const WorkflowsPage(),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Agentes'), findsOneWidget);
      expect(find.text('APIs LLM'), findsOneWidget);
      expect(find.byIcon(Icons.account_tree_outlined), findsNothing);
      expect(find.byIcon(Icons.hub_outlined), findsNothing);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.motion_photos_on_outlined), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.filter_list), findsOneWidget);
      await tester.tap(find.text('APIs LLM'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }
}
