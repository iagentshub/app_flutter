import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/workflows/pages/workflows_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/widgets/resource_toolbar.dart';
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
        if (request.url.path == '/api/workflows') {
          return http.Response('[]', 200);
        }
        if (request.url.path == '/api/v2/agents') {
          return http.Response(
            jsonEncode({
              'items': <Object>[],
              'page': {'has_more': false},
            }),
            200,
          );
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

      // Las dos pestañas van sin icono, solo con su nombre. La comprobación se
      // acota al `TabBar` y no a la página entera porque estos mismos iconos
      // son legítimos fuera de él: el del estado vacío ilustra la sección.
      Finder enLasPestanas(IconData icono) => find.descendant(
        of: find.byType(TabBar),
        matching: find.byIcon(icono),
      );
      expect(enLasPestanas(Icons.account_tree_outlined), findsNothing);
      expect(enLasPestanas(Icons.hub_outlined), findsNothing);

      // Igual con las acciones: el botón del estado vacío repite el «+» de la
      // barra a propósito —es la misma acción— así que contarlos en toda la
      // página daría dos y no diría nada de la barra.
      Finder enLaBarra(IconData icono) => find.descendant(
        of: find.byType(ResourceToolbar),
        matching: find.byIcon(icono),
      );
      expect(enLaBarra(Icons.add), findsOneWidget);
      expect(enLaBarra(Icons.motion_photos_on_outlined), findsOneWidget);
      expect(enLaBarra(Icons.refresh), findsOneWidget);
      expect(enLaBarra(Icons.filter_list), findsOneWidget);

      final tabBarWidth = tester.getSize(find.byType(TabBar)).width;
      expect(tabBarWidth, lessThanOrEqualTo(560));
      if (width > 560) {
        expect(tabBarWidth, closeTo(560, 0.1));
      }

      final toolbarBottom = tester
          .getBottomLeft(find.byType(ResourceToolbar))
          .dy;
      final emptyPanelTop = tester.getTopLeft(find.byType(Card).last).dy;
      expect(emptyPanelTop - toolbarBottom, lessThan(48));
      expect(
        tester.getSize(find.byType(Card).last).width,
        lessThanOrEqualTo(680),
      );

      await tester.tap(find.text('APIs LLM'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
    });
  }
}
