import 'dart:convert';

import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    controller = await BackendController.bootstrap();
  });

  test('usa HTTPS por defecto para hosts públicos', () {
    expect(
      controller.normalizeBackendInput('api.example.com/v1/'),
      'https://api.example.com/v1',
    );
  });

  test('rechaza HTTP público y credenciales embebidas', () {
    expect(controller.normalizeBackendInput('http://api.example.com'), isEmpty);
    expect(
      controller.normalizeBackendInput('https://user:pass@example.com'),
      isEmpty,
    );
  });

  test('permite HTTP únicamente para destinos locales o privados', () {
    expect(
      controller.normalizeBackendInput('localhost:8765'),
      'http://localhost:8765',
    );
    expect(
      controller.normalizeBackendInput('http://192.168.1.20:8765'),
      'http://192.168.1.20:8765',
    );
    expect(
      controller.normalizeBackendInput('http://service.local:8765'),
      'http://service.local:8765',
    );
    expect(
      controller.normalizeBackendInput('http://fcorp.example.com'),
      isEmpty,
    );
  });

  test('rechaza puertos, query y fragmentos inválidos para una base URL', () {
    expect(
      controller.normalizeBackendInput('https://example.com:99999'),
      isEmpty,
    );
    expect(
      controller.normalizeBackendInput('https://example.com?token=secret'),
      isEmpty,
    );
    expect(
      controller.normalizeBackendInput('https://example.com/#fragment'),
      isEmpty,
    );
  });

  test('solo marca OK una respuesta compatible de iAgents Hub', () async {
    controller = await BackendController.bootstrap(
      pingClient: MockClient(
        (_) async => http.Response(
          jsonEncode({'service': 'iagentshub', 'api_version': 1}),
          200,
        ),
      ),
    );

    final result = await controller.pingBackend('https://backend.example.com');

    expect(result.ok, isTrue);
    expect(result.statusCode, 200);
  });

  test(
    'un HTTP 200 que no es la API de iAgents Hub se marca como fallo',
    () async {
      controller = await BackendController.bootstrap(
        pingClient: MockClient(
          (_) async => http.Response('<html>Portal</html>', 200),
        ),
      );

      final result = await controller.pingBackend(
        'https://backend.example.com',
      );

      expect(result.ok, isFalse);
      expect(result.statusCode, 200);
      expect(result.error, contains('JSON'));
    },
  );

  test('mantiene compatibilidad con el contrato público anterior', () async {
    controller = await BackendController.bootstrap(
      pingClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'registration': 'open',
            'guest_enabled': true,
            'billing_enabled': false,
          }),
          200,
        ),
      ),
    );

    final result = await controller.pingBackend('https://backend.example.com');

    expect(result.ok, isTrue);
  });
}
