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

  testWidgets('ofrece los dos documentos dentro de la frase de la casilla', (
    tester,
  ) async {
    await _pumpRegister(tester);

    // Los enlaces ya no son dos botones debajo, sino tramos de la propia
    // frase que se acepta, así que hay que mirar el texto compuesto.
    final frase = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((w) => w.text.toPlainText())
        .firstWhere((t) => t.contains('acepto'), orElse: () => '');

    expect(frase, contains('términos y condiciones'));
    expect(frase, contains('política de privacidad'));
  });

  testWidgets('con el registro cerrado no hay formulario que enviar', (
    tester,
  ) async {
    await _pumpRegister(tester, registration: 'closed');

    // Antes se pintaban los tres campos en gris con la casilla deshabilitada.
    // Ahora no se pinta nada: sin casilla y sin botón no hay forma de mandar
    // un alta, que es la garantía que este test protege.
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(PrimaryButton), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(
      find.text('Registro deshabilitado en este backend. Contacta con el '
          'administrador.'),
      findsOneWidget,
    );
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
