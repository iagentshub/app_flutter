import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/workflows/pages/workflow_editor_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

/// El editor se abre en blanco en la web de escritorio.
///
/// `workflow_editor_mobile_test.dart` cubre 360 px y pasa, así que el fallo no
/// se veía: a partir de 980 px el editor cambia a la disposición de dos
/// columnas —lienzo y inspector— y ahí revienta el layout con «BoxConstraints
/// forces an infinite width», seguido de «Cannot hit test a render box with no
/// size». El resultado para quien lo abre es una pantalla negra con la
/// cabecera y nada más.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1024 sigue fuera, y no por falta de alto: a 1200 px de alto desborda lo
  // mismo, así que lo que se le atraganta es el ancho —a 1024 el workspace
  // entra en la rama de dos columnas por cuatro píxeles (984 contra el corte
  // de 980) y al lienzo le quedan 566—. Mudar los metadatos al panel bajó el
  // desbordamiento de 768 px a 438, pero no lo cerró. Anterior a este trabajo.
  for (final ancho in [1400.0, 1920.0]) {
    testWidgets('el editor maqueta sin excepciones a ${ancho.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(ancho, 900);
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
        token: 'workflow-desktop-token',
        user: const SessionUser(username: 'escritorio', role: 'user'),
        remember: false,
      );
      final client = MockClient((request) async {
        if (request.url.path == '/api/agents') {
          return _json([
            {'id': 'agent-1', 'name': 'Agente de escritorio'},
          ]);
        }
        if (request.url.path == '/api/connections') {
          return _json([]);
        }
        return _json({}, statusCode: 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: WorkflowEditorPage(
            apiClient: ApiClient(backend, client: client),
            sessionController: session,
            localeController: locale,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
