import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/auth/repositories/auth_repository.dart';
import 'package:app_flutter/features/dashboard/pages/dashboard_page.dart';
import 'package:app_flutter/features/dashboard/repositories/dashboard_repository.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/dashboard_edit_state.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/widgets/animated_iagents_mark.dart';
import 'package:app_flutter/shared/widgets/iagents_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el dashboard usa el logo animado mientras carga', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'user-token',
      user: const SessionUser(username: 'ada', role: 'user'),
      remember: false,
    );

    final pendingPreferences = Completer<http.Response>();
    final httpClient = MockClient((request) {
      if (request.url.path == '/api/settings/dashboard-layout-v2' &&
          request.method == 'GET') {
        return pendingPreferences.future;
      }
      return Future.value(
        http.Response(
          jsonEncode(<String, dynamic>{}),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
    });
    final apiClient = ApiClient(backend, client: httpClient);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppServicesScope(
            apiClient: apiClient,
            sessionController: session,
            localeController: locale,
            child: DashboardPage(
              backendController: backend,
              authRepository: AuthRepository(apiClient),
              dashboardRepository: DashboardRepository(apiClient),
              dashboardEditState: DashboardEditState(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 121));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(IAgentsLoadingIndicator), findsOneWidget);
    expect(find.byType(IAgentsLoadingMark), findsOneWidget);
    expect(find.text('Cargando…'), findsOneWidget);

    pendingPreferences.complete(
      http.Response(
        jsonEncode(<String, dynamic>{}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpAndSettle();
  });
}
