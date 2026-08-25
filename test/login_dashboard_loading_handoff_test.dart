import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/app/app.dart';
import 'package:app_flutter/features/dashboard/pages/dashboard_page.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/boot_platform_cache.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:app_flutter/shared/widgets/buttons/app_buttons.dart';
import 'package:app_flutter/shared/widgets/iagents_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  testWidgets('login y dashboard comparten un único overlay de carga', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({'app_language': 'es'});
    BootPlatformCache.set(
      platform: const {'registration': 'open', 'guest_enabled': false},
      reachable: true,
    );
    final backend = await BackendController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    final locale = await LocaleController.bootstrap();
    final theme = await ThemeController.bootstrap();
    final dashboardLayout = Completer<http.Response>();
    final requests = <String>[];

    final client = MockClient((request) {
      requests.add('${request.method} ${request.url.path}');
      switch ((request.method, request.url.path)) {
        case ('POST', '/api/auth/login'):
          return Future.value(
            http.Response(
              jsonEncode({'ok': true, 'username': 'ada'}),
              200,
              headers: {
                'content-type': 'application/json',
                'set-cookie': 'ga_token=user-token; Path=/; HttpOnly',
              },
            ),
          );
        case ('GET', '/api/auth/me'):
          return Future.value(
            http.Response(
              jsonEncode({'username': 'ada', 'role': 'user'}),
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
        case ('GET', '/api/settings/platform/public'):
          return Future.value(
            http.Response(
              jsonEncode({'registration': 'open', 'guest_enabled': false}),
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
        case ('GET', '/api/settings'):
          return Future.value(
            http.Response(
              '{}',
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
        case ('GET', '/api/settings/dashboard-layout-v2'):
          return dashboardLayout.future;
        default:
          return Future.value(
            http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
            ),
          );
      }
    });

    await tester.pumpWidget(
      ThemeControllerScope(
        controller: theme,
        child: App(
          backendController: backend,
          sessionController: session,
          localeController: locale,
          themeController: theme,
          httpClient: client,
        ),
      ),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 30; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 25));
      final button = tester.widget<PrimaryButton>(
        find.widgetWithText(PrimaryButton, 'Entrar'),
      );
      if (button.onPressed != null) break;
    }

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'ada');
    await tester.enterText(fields.at(1), 'secreto');
    await tester.pump();
    final loginButton = tester.widget<PrimaryButton>(
      find.widgetWithText(PrimaryButton, 'Entrar'),
    );
    expect(
      loginButton.onPressed,
      isNotNull,
      reason: 'El backend no habilitó el login. Peticiones: $requests',
    );
    loginButton.onPressed!();
    await tester.pump();

    for (var attempt = 0; attempt < 30; attempt += 1) {
      await tester.pump(const Duration(milliseconds: 25));
      if (find.byType(DashboardPage).evaluate().isNotEmpty) break;
    }

    expect(
      session.isLoggedIn,
      isTrue,
      reason: 'Peticiones realizadas: $requests',
    );
    expect(find.byType(DashboardPage), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 150));
    expect(
      find.byKey(const Key('login-dashboard-loading-overlay')),
      findsOneWidget,
    );
    expect(find.byType(IAgentsLoadingIndicator), findsOneWidget);
    final loadingText = find
        .descendant(
          of: find.byType(IAgentsLoadingIndicator),
          matching: find.byType(Text),
        )
        .first;
    expect(
      DefaultTextStyle.of(tester.element(loadingText)).style.decoration,
      TextDecoration.none,
    );

    dashboardLayout.complete(
      http.Response(
        jsonEncode({'version': 2, 'items': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(IAgentsLoadingIndicator), findsNothing);
    expect(find.byType(DashboardPage), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    locale.dispose();
    theme.dispose();
    session.dispose();
  });
}
