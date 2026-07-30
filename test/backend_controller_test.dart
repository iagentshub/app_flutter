import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
