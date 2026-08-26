import 'package:app_flutter/core/config/security_contract.dart';
import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/core/network/csrf_token.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El token anti-CSRF: se captura del `set-cookie` y viaja en la cabecera de
/// todo método con efectos. Fuera de web no hay cookie jar, así que estos
/// tests ejercitan la implementación de memoria (`csrf_token_stub.dart`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
    forgetCsrfToken();
  });

  tearDown(forgetCsrfToken);

  test('el contrato CSRF distingue la cookie exacta en cualquier posición', () {
    expect(
      SecurityContract.readCookieValue('ga_csrf=inicio', SecurityCookieId.csrf),
      'inicio',
    );
    expect(
      SecurityContract.readCookieValue(
        'a=1;  ga_csrf=medio; b=2',
        SecurityCookieId.csrf,
      ),
      'medio',
    );
    expect(
      SecurityContract.readCookieValue(
        'otra_ga_csrf=falsa',
        SecurityCookieId.csrf,
      ),
      isNull,
    );
    expect(
      SecurityContract.readCookieValue('ga_csrf=', SecurityCookieId.csrf),
      isNull,
    );
  });

  test(
    'el lector tipado extrae access y refresh de una cabecera combinada',
    () {
      const source = 'ga_token=access; Path=/, ga_refresh=refresh; HttpOnly';

      expect(
        SecurityContract.readCookieValue(source, SecurityCookieId.access),
        'access',
      );
      expect(
        SecurityContract.readCookieValue(source, SecurityCookieId.refresh),
        'refresh',
      );
    },
  );

  /// Cliente que anota las cabeceras de cada petición y devuelve la cookie
  /// `ga_csrf` en la primera respuesta, como hace el backend al iniciar sesión.
  ({ApiClient client, List<Map<String, String>> vistas}) montar() {
    final vistas = <Map<String, String>>[];
    var primera = true;
    final mock = MockClient((request) async {
      vistas.add(Map<String, String>.from(request.headers));
      final headers = {'content-type': 'application/json'};
      if (primera) {
        primera = false;
        headers['set-cookie'] = 'ga_csrf=token-de-sesion; Path=/; SameSite=Lax';
      }
      return http.Response('{"ok":true}', 200, headers: headers);
    });
    return (client: ApiClient(backendController, client: mock), vistas: vistas);
  }

  test('captura ga_csrf del set-cookie y lo reenvía en los POST', () async {
    final montaje = montar();
    addTearDown(montaje.client.close);

    await montaje.client.post('/api/auth/login', gaToken: 'sesion');
    expect(readCsrfToken(), 'token-de-sesion');

    await montaje.client.post('/api/agents', body: {'name': 'x'});
    expect(montaje.vistas.last['X-CSRF-Token'], 'token-de-sesion');
  });

  test('un GET no lleva la cabecera: el backend no la mira', () async {
    final montaje = montar();
    addTearDown(montaje.client.close);

    await montaje.client.post('/api/auth/login', gaToken: 'sesion');
    await montaje.client.get('/api/agents');
    expect(montaje.vistas.last.containsKey('X-CSRF-Token'), isFalse);
  });

  test('sin token capturado no se inventa la cabecera', () async {
    final montaje = montar();
    addTearDown(montaje.client.close);

    // La primera petición sale antes de que exista ninguna cookie.
    await montaje.client.post('/api/auth/login', gaToken: 'sesion');
    expect(montaje.vistas.first.containsKey('X-CSRF-Token'), isFalse);
  });

  test('el token se recoge también cuando el backend lo reemite', () async {
    // Es lo que cura las sesiones abiertas antes del despliegue: el backend
    // repone ga_csrf en cualquier respuesta, no solo al iniciar sesión.
    final vistas = <Map<String, String>>[];
    var n = 0;
    final mock = MockClient((request) async {
      vistas.add(Map<String, String>.from(request.headers));
      n += 1;
      final headers = {'content-type': 'application/json'};
      if (n == 2) headers['set-cookie'] = 'ga_csrf=repuesto; Path=/';
      return http.Response('{"ok":true}', 200, headers: headers);
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    await client.post('/api/agents', body: {'name': 'x'});
    expect(readCsrfToken(), isNull);

    await client.get('/api/auth/me'); // aquí el backend repone la cookie
    expect(readCsrfToken(), 'repuesto');

    await client.post('/api/agents', body: {'name': 'y'});
    expect(vistas.last['X-CSRF-Token'], 'repuesto');
  });
}
