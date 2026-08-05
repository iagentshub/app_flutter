import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/auth/pages/register_page.dart';
import 'package:app_flutter/features/auth/repositories/auth_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/widgets/buttons/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El registro no puede enviarse sin aceptar los términos: publicar los
/// documentos en la web no sirve de nada si nadie los acepta al crear la
/// cuenta, que es donde hay que poder demostrar el consentimiento.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('el botón de registro está bloqueado hasta aceptar lo legal', (
    tester,
  ) async {
    await _pumpRegister(tester);

    expect(_botonRegistro().onPressed, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(_botonRegistro().onPressed, isNotNull);
  });

  testWidgets('desmarcar la casilla vuelve a bloquear el envío', (
    tester,
  ) async {
    await _pumpRegister(tester);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(_botonRegistro().onPressed, isNull);
  });

  testWidgets('ofrece los dos documentos junto a la casilla', (tester) async {
    await _pumpRegister(tester);

    expect(find.text('Términos y condiciones'), findsOneWidget);
    expect(find.text('Política de privacidad'), findsOneWidget);
  });

  testWidgets('con el registro cerrado la casilla no se puede marcar', (
    tester,
  ) async {
    await _pumpRegister(tester, registration: 'closed');

    final casilla = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(casilla.onChanged, isNull);
  });
}

PrimaryButton _botonRegistro() {
  return find.byType(PrimaryButton).evaluate().single.widget as PrimaryButton;
}

Future<void> _pumpRegister(
  WidgetTester tester, {
  String registration = 'open',
}) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});

  final backend = await BackendController.bootstrap();
  final locale = await LocaleController.bootstrap();

  final client = MockClient((request) async {
    if (request.url.path == '/api/settings/platform/public') {
      return http.Response(
        jsonEncode({'registration': registration, 'billing_enabled': false}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response(
      '{}',
      200,
      headers: {'content-type': 'application/json'},
    );
  });

  await tester.pumpWidget(
    MaterialApp(
      home: RegisterPage(
        authRepository: AuthRepository(ApiClient(backend, client: client)),
        localeController: locale,
      ),
    ),
  );
  await tester.pumpAndSettle();
}
