import 'dart:async';

import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/auth/pages/login_page.dart';
import 'package:app_flutter/features/auth/repositories/auth_repository.dart';
import 'package:app_flutter/models/auth/auth_result.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/theme_controller.dart';
import 'package:app_flutter/shared/widgets/motion/app_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

/// Cuenta los envíos y no responde nunca: lo que se comprueba es que Enter
/// llega a `login`, no lo que pasa después.
class _CountingLoginRepository extends AuthRepository {
  _CountingLoginRepository(super.apiClient);

  var logins = 0;

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
  }) {
    logins++;
    return Completer<(AuthResult, String)>().future;
  }
}

void main() {
  /// Con ratón nadie lo nota; con teclado el diálogo se abre, Escape lo
  /// cierra y el foco tiene que volver al botón que lo abrió, no perderse.
  /// `showAppDialog` no es `showDialog` —es la ruta de `animations`— y esto
  /// fija que conserva las dos cosas.
  testWidgets('Escape cierra un diálogo y el foco vuelve a quien lo abrió', (
    tester,
  ) async {
    final opener = FocusNode();
    addTearDown(opener.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              focusNode: opener,
              autofocus: true,
              onPressed: () => showAppDialog<void>(
                context: context,
                builder: (_) =>
                    const AlertDialog(content: TextField(autofocus: true)),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(opener.hasFocus, isTrue);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(opener.hasFocus, isTrue);
  });

  testWidgets('en el login, Enter en la contraseña envía', (tester) async {
    SharedPreferences.setMockInitialValues({'app_language': 'es'});
    final backendController = await BackendController.bootstrap();
    final sessionController = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    final localeController = await LocaleController.bootstrap();
    final themeController = await ThemeController.bootstrap();
    final repository = _CountingLoginRepository(ApiClient(backendController));

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
    // `enterText` deja el foco en la contraseña; `done` es lo que manda el
    // teclado —físico o virtual— al pulsar Enter en un campo de una línea.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    await tester.pump();

    expect(repository.logins, 1);
  });
}
