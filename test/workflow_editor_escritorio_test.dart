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

/// El editor de orquestación, maquetado en anchos de escritorio.
///
/// Cubre dos fallos que solo salían aquí, porque la única prueba que existía
/// montaba 360 px y los dos viven por encima de ese corte.
///
/// `workflow_editor_mobile_test.dart` cubre 360 px y pasa, así que el fallo no
/// se veía: a partir de 980 px el editor cambia a la disposición de dos
/// columnas —lienzo y inspector— y ahí revienta el layout con «BoxConstraints
/// forces an infinite width», seguido de «Cannot hit test a render box with no
/// size». El resultado para quien lo abre es una pantalla negra con la
/// cabecera y nada más.
///
/// El segundo solo se veía entre ~980 y ~1050 px: el `Wrap` de acciones de la
/// barra iba suelto en un `Row`, recibía ancho no acotado y aplastaba al
/// título, que pasaba a envolver casi letra a letra. La barra llegaba a pedir
/// 1139 px de alto en lugar de ~86 y desbordaba la columna por abajo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 1024 estuvo fuera de esta lista mientras la barra del editor se comía la
  // columna. Ahora entra, y es el ancho que importa: por debajo de ~1050 es
  // donde el `Wrap` de acciones aplastaba al título.
  for (final ancho in [1024.0, 1400.0, 1920.0]) {
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
        if (request.url.path == '/api/v2/agents') {
          return _json({
            'items': [
              {'id': 'agent-1', 'name': 'Agente de escritorio'},
            ],
            'page': {'has_more': false},
          });
        }
        if (request.url.path == '/api/v2/connections') {
          return _json({
            'items': [],
            'page': {'has_more': false},
          });
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
