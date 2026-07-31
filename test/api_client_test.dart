import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/core/network/api_error.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
  });

  test('agrupa GET cacheables simultáneos y reutiliza la respuesta', () async {
    var calls = 0;
    final mock = MockClient((request) async {
      calls += 1;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return http.Response(
        '{"value":1}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    final responses = await Future.wait([
      client.get('/api/items', gaToken: 'session-a', cache: true),
      client.get('/api/items', gaToken: 'session-a', cache: true),
    ]);
    final cached = await client.get(
      '/api/items',
      gaToken: 'session-a',
      cache: true,
    );

    expect(calls, 1);
    expect(responses[0].json['value'], 1);
    expect(responses[1].json['value'], 1);
    expect(cached.json['value'], 1);
    expect(client.debugInFlightGetCount, 0);
  });

  test('separa la caché por sesión e invalida tras una mutación', () async {
    var getCalls = 0;
    final mock = MockClient((request) async {
      if (request.method == 'GET') {
        getCalls += 1;
        return http.Response('{"call":$getCalls}', 200);
      }
      return http.Response('{}', 200);
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    await client.get('/api/items', gaToken: 'session-a', cache: true);
    await client.get('/api/items', gaToken: 'session-b', cache: true);
    await client.get('/api/items', gaToken: 'session-a', cache: true);
    expect(getCalls, 2);

    await client.post('/api/items', gaToken: 'session-a', body: {});
    await client.get('/api/items', gaToken: 'session-a', cache: true);
    expect(getCalls, 3);
  });

  test('una mutación impide cachear un GET que ya estaba en vuelo', () async {
    var getCalls = 0;
    final firstGetStarted = Completer<void>();
    final firstGetResponse = Completer<http.Response>();
    final mock = MockClient((request) async {
      if (request.method == 'GET') {
        getCalls += 1;
        if (getCalls == 1) {
          firstGetStarted.complete();
          return firstGetResponse.future;
        }
        return http.Response('{"call":$getCalls}', 200);
      }
      return http.Response('{}', 200);
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    final staleGet = client.get('/api/items', gaToken: 'session', cache: true);
    await firstGetStarted.future;
    await client.post('/api/items', gaToken: 'session', body: {});
    firstGetResponse.complete(http.Response('{"call":1}', 200));
    await staleGet;
    final fresh = await client.get(
      '/api/items',
      gaToken: 'session',
      cache: true,
    );

    expect(getCalls, 2);
    expect(fresh.json['call'], 2);
  });

  test('separa la caché al cambiar de backend', () async {
    var calls = 0;
    final hosts = <String>[];
    final mock = MockClient((request) async {
      calls += 1;
      hosts.add(request.url.host);
      return http.Response('{"host":"${request.url.host}"}', 200);
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    await client.get('/api/items', gaToken: 'session', cache: true);
    final local = await backendController.addBackend(
      name: 'Local',
      url: 'http://localhost:8765',
    );
    await backendController.setSelectedBackend(local.id);
    await client.get('/api/items', gaToken: 'session', cache: true);

    expect(calls, 2);
    expect(hosts, ['www.iagentshub.com', 'localhost']);
  });

  test('limita el número de entradas retenidas en caché', () async {
    final mock = MockClient((request) async => http.Response('{}', 200));
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    for (var i = 0; i < 205; i++) {
      await client.get('/api/items/$i', gaToken: 'session', cache: true);
    }

    expect(client.debugCacheEntryCount, 200);
  });

  test('aplica timeout y reporta el backend como no alcanzable', () async {
    final mock = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return http.Response('{}', 200);
    });
    final client = ApiClient(
      backendController,
      client: mock,
      requestTimeout: const Duration(milliseconds: 5),
    );
    addTearDown(client.close);

    await expectLater(
      client.get('/api/slow'),
      throwsA(isA<TimeoutException>()),
    );
    expect(backendController.hasConnectionIssue, isTrue);
  });

  test('rechaza respuestas que superan el límite de memoria', () async {
    final mock = MockClient(
      (request) async => http.Response('0123456789', 200),
    );
    final client = ApiClient(
      backendController,
      client: mock,
      maxResponseBytes: 8,
    );
    addTearDown(client.close);

    await expectLater(
      client.get('/api/large'),
      throwsA(
        isA<ApiError>().having(
          (error) => error.code,
          'code',
          'response_too_large',
        ),
      ),
    );
  });

  test('SSE separa correctamente CRLF y la última línea', () async {
    final mock = MockClient(
      (request) async => http.Response(
        'data: uno\r\ndata: dos\r\nfinal',
        200,
        headers: {'content-type': 'text/event-stream'},
      ),
    );
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    final lines = await client
        .postStream('/api/stream', body: {'input': 'hola'})
        .toList();

    expect(lines, ['data: uno', 'data: dos', 'final']);
  });

  test('SSE rechaza eventos sin terminador que crecen sin límite', () async {
    final mock = MockClient(
      (request) async => http.Response('data: 0123456789', 200),
    );
    final client = ApiClient(
      backendController,
      client: mock,
      maxStreamLineChars: 8,
    );
    addTearDown(client.close);

    await expectLater(
      client.getStream('/api/stream').toList(),
      throwsA(
        isA<ApiError>().having(
          (error) => error.code,
          'code',
          'stream_event_too_large',
        ),
      ),
    );
  });

  test('sanea nombres de descarga recibidos del servidor', () async {
    final mock = MockClient(
      (request) async => http.Response.bytes(
        utf8.encode('zip'),
        200,
        headers: {
          'content-disposition': 'attachment; filename="../../secret.zip"',
        },
      ),
    );
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    final result = await client.getBytes('/api/export');

    expect(result.filename, 'secret.zip');
  });

  test(
    'no sigue redirects automáticamente en peticiones autenticadas',
    () async {
      final followRedirects = <bool>[];
      final mock = MockClient((request) async {
        followRedirects.add(request.followRedirects);
        return http.Response('{}', 200);
      });
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);

      await client.get('/api/items', gaToken: 'session');
      await client.post('/api/items', gaToken: 'session', body: {});
      await client.getBytes('/api/export', gaToken: 'session');

      expect(followRedirects, everyElement(isFalse));
    },
  );
}
