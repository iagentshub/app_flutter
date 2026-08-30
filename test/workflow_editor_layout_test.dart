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

  testWidgets('mantiene el espacio de trabajo estable en escritorio', (
    tester,
  ) async {
    final harness = await _EditorHarness.create();
    addTearDown(harness.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final width in [1440.0, 1024.0, 720.0]) {
      tester.view.physicalSize = Size(width, 820);
      await tester.pumpWidget(harness.build(key: ValueKey(width)));
      await tester.pumpAndSettle();

      final canvas = find.byKey(const ValueKey('workflow-editor-canvas-pane'));
      final inspector = find.byKey(const ValueKey('workflow-editor-inspector'));
      expect(canvas, findsOneWidget);
      expect(inspector, findsOneWidget);
      expect(find.text('Lienzo de orquestación'), findsNothing);
      expect(tester.takeException(), isNull);

      final canvasRect = tester.getRect(canvas);
      final inspectorRect = tester.getRect(inspector);
      if (width >= 980) {
        expect(canvasRect.top, inspectorRect.top);
        expect(canvasRect.right, lessThanOrEqualTo(inspectorRect.left));
      } else {
        expect(canvasRect.bottom, lessThanOrEqualTo(inspectorRect.top));
      }
    }
  });

  testWidgets('el contador abre problemas y estos devuelven al paso', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _EditorHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(harness.build());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('workflow-issues-button')));
    await tester.pumpAndSettle();
    final issues = find.byKey(const ValueKey('workflow-inspector-issues'));
    expect(issues.hitTestable(), findsOneWidget);

    final firstIssue = find
        .descendant(of: issues, matching: find.byType(InkWell))
        .first;
    await tester.tap(firstIssue);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-inspector-step')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserva la jerarquía visual en tema oscuro', (tester) async {
    tester.view.physicalSize = const Size(1200, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final harness = await _EditorHarness.create();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      harness.build(theme: ThemeData.dark(useMaterial3: true)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workflow-editor-canvas-pane')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workflow-editor-inspector')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

class _EditorHarness {
  _EditorHarness({
    required this.backend,
    required this.locale,
    required this.session,
    required this.client,
  });

  final BackendController backend;
  final LocaleController locale;
  final SessionController session;
  final MockClient client;

  static Future<_EditorHarness> create() async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'workflow-layout-token',
      user: const SessionUser(username: 'layout', role: 'user'),
      remember: false,
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/agents') {
        return _json([
          {'id': 'agent-1', 'name': 'Agente de prueba'},
        ]);
      }
      if (request.url.path == '/api/connections') return _json([]);
      return _json({}, statusCode: 404);
    });
    return _EditorHarness(
      backend: backend,
      locale: locale,
      session: session,
      client: client,
    );
  }

  Widget build({Key? key, ThemeData? theme}) => MaterialApp(
    theme: theme,
    home: WorkflowEditorPage(
      key: key,
      apiClient: ApiClient(backend, client: client),
      sessionController: session,
      localeController: locale,
    ),
  );

  void dispose() {
    client.close();
    session.dispose();
    locale.dispose();
    backend.dispose();
  }
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
