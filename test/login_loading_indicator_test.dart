import 'dart:async';

import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/auth/pages/login_page.dart';
import 'package:app_flutter/features/auth/repositories/auth_repository.dart';
import 'package:app_flutter/models/auth/auth_result.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:app_flutter/shared/widgets/animated_iagents_mark.dart';
import 'package:app_flutter/shared/widgets/iagents_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

class _PendingLoginRepository extends AuthRepository {
  _PendingLoginRepository(super.apiClient);

  final loginCompleter = Completer<(AuthResult, String)>();

  @override
  Future<Map<String, dynamic>> platformPublic() async => {
    'registration': 'open',
    'billing_enabled': false,
    'guest_enabled': false,
  };

  @override
  Future<(AuthResult, String)> login({
    required String identifier,
    required String password,
  }) => loginCompleter.future;
}

class _SuccessfulLoginRepository extends _PendingLoginRepository {
  _SuccessfulLoginRepository(super.apiClient);

  @override
  Future<SessionUser> me(String gaToken, {Duration? timeout}) async =>
      const SessionUser(username: 'usuario', role: 'user');

  @override
  Future<Map<String, dynamic>> getSettings(String gaToken) async => const {};
}

void main() {
  testWidgets('el login superpone la espera y difumina el formulario', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'es'});
    final backendController = await BackendController.bootstrap();
    final sessionController = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    final localeController = await LocaleController.bootstrap();
    final themeController = await ThemeController.bootstrap();
    final repository = _PendingLoginRepository(ApiClient(backendController));

    await tester.pumpWidget(
      ThemeControllerScope(
        controller: themeController,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: LoginPage(
            backendController: backendController,
            sessionController: sessionController,
            localeController: localeController,
            authRepository: repository,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'usuario');
    await tester.enterText(fields.at(1), 'secreto');
    // El login es una sola columna que scrollea: en el alto de prueba
    // (600 px) el botón cae por debajo del pliegue, igual que en un
    // teléfono real. Lo que se comprueba aquí es el overlay de espera,
    // no dónde queda el botón.
    await tester.ensureVisible(find.text('Entrar'));
    await tester.pump();
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byKey(const Key('login-loading-overlay')), findsOneWidget);
    final overlay = find.byKey(const Key('iagents-loading-overlay'));
    expect(overlay, findsOneWidget);
    expect(
      find.descendant(
        of: overlay,
        matching: find.byType(IAgentsLoadingIndicator),
      ),
      findsOneWidget,
    );
    expect(find.byType(ImageFiltered), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Cargando…'), findsOneWidget);
    expect(
      find.descendant(of: overlay, matching: find.byType(IAgentsLoadingMark)),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    localeController.dispose();
    themeController.dispose();
    sessionController.dispose();
  });

  testWidgets('mantiene el overlay hasta que el router desmonta el login', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'es'});
    final backendController = await BackendController.bootstrap();
    final sessionController = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    final localeController = await LocaleController.bootstrap();
    final themeController = await ThemeController.bootstrap();
    final repository = _SuccessfulLoginRepository(ApiClient(backendController));

    await tester.pumpWidget(
      ThemeControllerScope(
        controller: themeController,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: LoginPage(
            backendController: backendController,
            sessionController: sessionController,
            localeController: localeController,
            authRepository: repository,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'usuario');
    await tester.enterText(fields.at(1), 'secreto');
    // El login es una sola columna que scrollea: en el alto de prueba
    // (600 px) el botón cae por debajo del pliegue, igual que en un
    // teléfono real. Lo que se comprueba aquí es el overlay de espera,
    // no dónde queda el botón.
    await tester.ensureVisible(find.text('Entrar'));
    await tester.pump();
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    repository.loginCompleter.complete((
      const AuthResult(ok: true, username: 'usuario'),
      'user-token',
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(sessionController.isLoggedIn, isTrue);
    final overlay = find.byKey(const Key('iagents-loading-overlay'));
    expect(overlay, findsOneWidget);
    expect(
      find.descendant(
        of: overlay,
        matching: find.byType(IAgentsLoadingIndicator),
      ),
      findsOneWidget,
    );
    expect(find.text('Cargando…'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    localeController.dispose();
    themeController.dispose();
    sessionController.dispose();
  });
}
