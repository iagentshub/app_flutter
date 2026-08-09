import 'dart:convert';

import 'package:app_flutter/features/auth/pages/backend_config_page.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> get _compatiblePlatform => {
  'service': 'iagentshub',
  'api_version': 1,
};

Future<({BackendController backend, LocaleController locale})> _controllers(
  MockClient client,
) async {
  SharedPreferences.setMockInitialValues({});
  return (
    backend: await BackendController.bootstrap(pingClient: client),
    locale: await LocaleController.bootstrap(),
  );
}

Future<void> _openAndVerifyBackend(WidgetTester tester) async {
  await tester.tap(find.text('Añadir backend'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).at(0), 'Servidor de casa');
  await tester.enterText(
    find.byType(TextFormField).at(1),
    'backend.example.com',
  );
  await tester.tap(find.text('Comprobar conexión'));
  await tester.pumpAndSettle();
  expect(find.text('Conexión OK'), findsOneWidget);
}

void main() {
  testWidgets('añade y selecciona el backend verificado', (tester) async {
    final controllers = await _controllers(
      MockClient(
        (_) async => http.Response(jsonEncode(_compatiblePlatform), 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BackendConfigPage(
          backendController: controllers.backend,
          localeController: controllers.locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openAndVerifyBackend(tester);

    await tester.tap(find.text('Añadir a la lista'));
    await tester.pumpAndSettle();

    expect(controllers.backend.savedBackends, hasLength(1));
    expect(
      controllers.backend.selectedBackendId,
      controllers.backend.savedBackends.single.id,
    );
    expect(controllers.backend.effectiveBaseUrl, 'https://backend.example.com');
  });

  testWidgets('no guarda si falla la comprobación final', (tester) async {
    var customBackendRequests = 0;
    final controllers = await _controllers(
      MockClient((request) async {
        if (request.url.host == 'backend.example.com') {
          customBackendRequests++;
          if (customBackendRequests > 1) {
            return http.Response('Unavailable', 503);
          }
        }
        return http.Response(jsonEncode(_compatiblePlatform), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BackendConfigPage(
          backendController: controllers.backend,
          localeController: controllers.locale,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _openAndVerifyBackend(tester);

    await tester.tap(find.text('Añadir a la lista'));
    await tester.pumpAndSettle();

    expect(controllers.backend.savedBackends, isEmpty);
    expect(find.text('El servidor respondió HTTP 503'), findsOneWidget);
  });
}
