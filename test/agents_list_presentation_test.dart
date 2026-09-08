import 'dart:convert';

import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/agents/cards/agent_card.dart';
import 'package:app_flutter/features/agents/pages/agents_page.dart';
import 'package:app_flutter/features/agents/widgets/agent_compact_tile.dart';
import 'package:app_flutter/features/agents/widgets/agent_list_order.dart';
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

import 'support/i18n_de_prueba.dart';
import 'support/memory_secure_store.dart';

void main() {
  testWidgets('agents retain sort and search while changing presentation', (
    tester,
  ) async {
    cargarTraduccionesDePrueba();
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1000);
    addTearDown(tester.view.reset);
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'test-token',
      user: const SessionUser(username: 'tester', role: 'user'),
      remember: false,
    );
    final client = MockClient((request) async {
      final body = switch (request.url.path) {
        '/api/v2/agents' => {
          'items': [
            for (final name in ['Zeta', 'Alfa'])
              {
                'id': name,
                'name': name,
                'scope': 'private',
                'connection_id': 'connection',
                'model': 'Model',
                'is_active': true,
              },
          ],
          'page': {'has_more': false},
        },
        '/api/v2/connections' => {
          'items': [
            {
              'id': 'connection',
              'name': 'Demo',
              'model': 'Model',
              'type': 'openai',
            },
          ],
          'page': {'has_more': false},
        },
        _ => <String, dynamic>{},
      };
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: AppServicesScope(
            apiClient: ApiClient(backend, client: client),
            sessionController: session,
            localeController: locale,
            child: const AgentsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<AgentCard>(find.byType(AgentCard))
          .map((card) => card.item.name),
      ['Zeta', 'Alfa'],
    );
    await tester.tap(find.byType(PopupMenuButton<AgentListOrder>));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is CheckedPopupMenuItem<AgentListOrder> &&
            widget.value == AgentListOrder.name,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<AgentCard>(find.byType(AgentCard))
          .map((card) => card.item.name),
      ['Alfa', 'Zeta'],
    );
    await tester.tap(find.byTooltip('Vista compacta'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widgetList<AgentCompactTile>(find.byType(AgentCompactTile))
          .map((tile) => tile.item.name),
      ['Alfa', 'Zeta'],
    );
    await tester.enterText(find.byType(TextField), 'Zeta');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.byType(AgentCompactTile), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
    expect(find.byType(AgentCompactTile), findsNWidgets(2));
    tester.view.physicalSize = const Size(360, 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    backend.dispose();
    locale.dispose();
    session.dispose();
  });
}
