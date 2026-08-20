import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/core/network/api_error.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// La renovación de sesión ante un 401 — punto 06 de la revisión.
///
/// El access dura 30 minutos y el refresh **rota** en cada canje: si el cliente
/// lanzase una renovación por cada petición que recibe 401, la segunda llegaría
/// con un refresh ya rotado, que el backend interpreta —correctamente— como
/// robo y revoca la sesión entera. Por eso el cerrojo es parte del contrato y
/// no un detalle de implementación.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
  });

  ApiClient construir(
    http.Client mock, {
    void Function(String)? onRenewed,
    void Function(String)? onRefreshSeen,
    String? refresh = 'iar_guardado',
  }) {
    final client = ApiClient(
      backendController,
      client: mock,
      onSessionRenewed: onRenewed,
      onRefreshTokenSeen: onRefreshSeen,
      refreshTokenProvider: () => refresh,
    );
    addTearDown(client.close);
    return client;
  }

  test('un 401 renueva la sesión y reintenta la petición', () async {
    var intentos = 0;
    var renovaciones = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        renovaciones += 1;
        return http.Response(
          '{"ok":true}',
          200,
          headers: {'set-cookie': 'ga_token=nuevo; ga_refresh=iar_nuevo'},
        );
      }
      intentos += 1;
      if (intentos == 1) return http.Response('{"detail":{}}', 401);
      return http.Response('{"value":1}', 200);
    });

    String? renovado;
    final client = construir(mock, onRenewed: (t) => renovado = t);
    final response = await client.get('/api/items', gaToken: 'viejo');

    expect(response.statusCode, 200);
    expect(intentos, 2, reason: 'no reintentó tras renovar');
    expect(renovaciones, 1);
    expect(renovado, 'nuevo');
  });

  test('el reintento va con el token nuevo, no con el caducado', () async {
    final tokensVistos = <String>[];
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        return http.Response(
          '{"ok":true}',
          200,
          headers: {'set-cookie': 'ga_token=nuevo; ga_refresh=iar_nuevo'},
        );
      }
      tokensVistos.add(request.headers['Cookie'] ?? '');
      return http.Response('{}', tokensVistos.length == 1 ? 401 : 200);
    });

    await construir(mock).get('/api/items', gaToken: 'viejo');

    expect(tokensVistos.first, contains('ga_token=viejo'));
    expect(tokensVistos.last, contains('ga_token=nuevo'));
  });

  test('varias peticiones en vuelo comparten una sola renovación', () async {
    var renovaciones = 0;
    final yaFallo = <String>{};
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        renovaciones += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response(
          '{"ok":true}',
          200,
          headers: {'set-cookie': 'ga_token=nuevo; ga_refresh=iar_nuevo'},
        );
      }
      final path = request.url.path;
      if (yaFallo.add(path)) return http.Response('{}', 401);
      return http.Response('{}', 200);
    });

    final client = construir(mock);
    await Future.wait([
      client.get('/api/a', gaToken: 'viejo'),
      client.get('/api/b', gaToken: 'viejo'),
      client.get('/api/c', gaToken: 'viejo'),
    ]);

    expect(
      renovaciones,
      1,
      reason: 'sin cerrojo, el refresh rotado tumbaría la sesión',
    );
  });

  test('si la renovación falla, el 401 llega a quien llamó', () async {
    var renovaciones = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) {
        renovaciones += 1;
        return http.Response('{"detail":{"code":"session_revoked"}}', 401);
      }
      return http.Response('{"detail":{"code":"session_revoked"}}', 401);
    });

    final client = construir(mock);
    await expectLater(
      client.get('/api/items', gaToken: 'viejo'),
      throwsA(isA<ApiError>().having((e) => e.statusCode, 'status', 401)),
    );
    expect(renovaciones, 1, reason: 'no debe reintentar la renovación');
  });

  test('sin sesión no se intenta renovar nada', () async {
    var renovaciones = 0;
    final mock = MockClient((request) async {
      if (request.url.path.endsWith('/auth/refresh')) renovaciones += 1;
      return http.Response('{"detail":{}}', 401);
    });

    final client = construir(mock, refresh: null);
    await expectLater(client.get('/api/auth/me'), throwsA(isA<ApiError>()));
    expect(renovaciones, 0, reason: 'el 401 del login no es una sesión caduca');
  });

  test('el refresh del login se captura sin que nadie lo pida', () async {
    // Seis emisores devuelven `ga_refresh`; recogerlo en cada uno es la forma
    // de que al séptimo se le olvide.
    final vistos = <String>[];
    final mock = MockClient((request) async {
      return http.Response(
        '{"ok":true}',
        200,
        headers: {'set-cookie': 'ga_token=t; ga_refresh=iar_delogin'},
      );
    });

    final client = construir(mock, onRefreshSeen: vistos.add);
    await client.post('/api/auth/login', body: {'x': 1});

    expect(vistos, ['iar_delogin']);
  });
}
