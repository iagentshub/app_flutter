import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/pages/admin_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/widgets/iagents_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  testWidgets('Admin carga sobre su contenido difuminado y muestra mensajes', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'es'});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'admin-token',
      user: const SessionUser(username: 'admin', role: 'admin'),
      remember: false,
    );

    final loadGate = Completer<void>();
    final client = MockClient((request) async {
      await loadGate.future;
      final Object body = switch (request.url.path) {
        '/api/v2/admin/explore' => const {
          'items': <Object>[],
          'page': {'has_more': false, 'total': 0},
          'counts': <String, Object>{},
        },
        _ => const <String, Object>{},
      };
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('admin-loading-overlay')), findsOneWidget);
    expect(find.byType(IAgentsLoadingIndicator), findsOneWidget);
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.text('Cargando…'), findsOneWidget);
    expect(find.byType(Tab), findsNWidgets(4));

    loadGate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(IAgentsLoadingIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    locale.dispose();
    session.dispose();
  });
}
