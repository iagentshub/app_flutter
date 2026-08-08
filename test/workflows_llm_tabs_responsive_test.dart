import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/workflows/pages/workflows_page.dart';
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
      final client = MockClient((_) async => http.Response('{}', 404));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkflowsPage(
              apiClient: ApiClient(backend, client: client),
              sessionController: session,
              localeController: locale,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Agentes'), findsOneWidget);
      expect(find.text('APIs LLM'), findsOneWidget);
      await tester.tap(find.text('APIs LLM'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byIcon(Icons.hub_outlined), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
