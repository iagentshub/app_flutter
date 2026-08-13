import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/app/app.dart';
import 'package:app_flutter/features/auth/pages/login_page.dart';
import 'package:app_flutter/features/auth/pages/session_recovery_page.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(WidgetTester tester, bool Function() condition) async {
    for (var attempt = 0; attempt < 40 && !condition(); attempt += 1) {
      await tester.pump(const Duration(milliseconds: 25));
    }
    expect(
      condition(),
      isTrue,
      reason: 'La interfaz no alcanzó el estado esperado',
    );
  }

  Future<
    ({
      BackendController backend,
      SessionController session,
      LocaleController locale,
      ThemeController theme,
      MemorySecureStore secrets,
    })
  >
  restoredSession() async {
    SharedPreferences.setMockInitialValues({
      'session_username': 'alice',
      'session_role': 'admin',
    });
    final secrets = MemorySecureStore()..values['ga_token'] = 'saved-token';
    final values = await Future.wait([
      BackendController.bootstrap(),
      SessionController.bootstrap(secureStore: secrets),
      LocaleController.bootstrap(),
      ThemeController.bootstrap(),
    ]);
    return (
      backend: values[0] as BackendController,
      session: values[1] as SessionController,
      locale: values[2] as LocaleController,
      theme: values[3] as ThemeController,
      secrets: secrets,
    );
  }

  Widget app(
    ({
      BackendController backend,
      SessionController session,
      LocaleController locale,
      ThemeController theme,
      MemorySecureStore secrets,
    })
    state,
    http.Client client,
  ) => App(
    backendController: state.backend,
    sessionController: state.session,
    localeController: state.locale,
    themeController: state.theme,
    httpClient: client,
    requestTimeout: const Duration(milliseconds: 100),
    sessionValidationTimeout: const Duration(milliseconds: 100),
  );

  testWidgets('no abre dashboard antes de validar la sesión guardada', (
    tester,
  ) async {
    final state = await restoredSession();
    final response = Completer<http.Response>();
    final client = MockClient((_) => response.future);

    await tester.pumpWidget(app(state, client));
    await tester.pump();

    expect(state.session.status, SessionStatus.restoring);
    expect(find.byType(SessionRecoveryPage), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    response.complete(
      http.Response(
        jsonEncode({'username': 'alice', 'role': 'user'}),
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    await pumpUntil(
      tester,
      () =>
          state.session.status == SessionStatus.authenticated &&
          find.byType(SessionRecoveryPage).evaluate().isEmpty,
    );

    expect(state.session.status, SessionStatus.authenticated);
    expect(find.byType(SessionRecoveryPage), findsNothing);
  });

  testWidgets('token caducado se elimina y termina en login', (tester) async {
    final state = await restoredSession();
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({'detail': 'expired'}),
        401,
        headers: {'content-type': 'application/json'},
      ),
    );

    await tester.pumpWidget(app(state, client));
    await pumpUntil(
      tester,
      () =>
          state.session.status == SessionStatus.signedOut &&
          find.byType(LoginPage).evaluate().isNotEmpty,
    );

    expect(state.session.status, SessionStatus.signedOut);
    expect(state.session.gaToken, isNull);
    expect(state.secrets.values['ga_token'], isNull);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('sin servidor conserva credenciales pero bloquea dashboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = await restoredSession();
    final client = MockClient((_) async => throw const SocketException('down'));

    await tester.pumpWidget(app(state, client));
    await pumpUntil(
      tester,
      () =>
          state.session.status == SessionStatus.backendUnavailable &&
          find
              .byKey(const ValueKey('session-retry-button'))
              .evaluate()
              .isNotEmpty,
    );

    expect(state.session.status, SessionStatus.backendUnavailable);
    expect(state.session.gaToken, 'saved-token');
    expect(state.secrets.values['ga_token'], 'saved-token');
    expect(find.byType(SessionRecoveryPage), findsOneWidget);
    expect(find.byKey(const ValueKey('session-retry-button')), findsOneWidget);
  });

  testWidgets('limita la espera de validación aunque la conexión no responda', (
    tester,
  ) async {
    final state = await restoredSession();
    final neverResponds = Completer<http.Response>();
    final client = MockClient((_) => neverResponds.future);

    await tester.pumpWidget(
      App(
        backendController: state.backend,
        sessionController: state.session,
        localeController: state.locale,
        themeController: state.theme,
        httpClient: client,
        requestTimeout: const Duration(seconds: 30),
        sessionValidationTimeout: const Duration(milliseconds: 50),
      ),
    );
    await tester.pump(const Duration(milliseconds: 49));
    expect(state.session.status, SessionStatus.restoring);

    await tester.pump(const Duration(milliseconds: 2));
    await pumpUntil(
      tester,
      () =>
          state.session.status == SessionStatus.backendUnavailable &&
          find
              .byKey(const ValueKey('session-retry-button'))
              .evaluate()
              .isNotEmpty,
    );
  });

  testWidgets('usar otra cuenta descarta la sesión conservada', (tester) async {
    final state = await restoredSession();
    final client = MockClient((_) async => throw const SocketException('down'));

    await tester.pumpWidget(app(state, client));
    await pumpUntil(
      tester,
      () =>
          state.session.status == SessionStatus.backendUnavailable &&
          find
              .byKey(const ValueKey('session-use-another-account-button'))
              .evaluate()
              .isNotEmpty,
    );
    final useAnother = find.byKey(
      const ValueKey('session-use-another-account-button'),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.ensureVisible(useAnother);
    await tester.pump();
    await tester.tap(useAnother);
    await pumpUntil(
      tester,
      () =>
          state.session.status == SessionStatus.signedOut &&
          find.byType(LoginPage).evaluate().isNotEmpty,
    );

    expect(state.session.status, SessionStatus.signedOut);
    expect(state.session.gaToken, isNull);
    expect(state.secrets.values['ga_token'], isNull);
    expect(find.byType(LoginPage), findsOneWidget);
  });
}
