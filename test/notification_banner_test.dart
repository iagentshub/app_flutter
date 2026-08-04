import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/repositories/admin_repository.dart';
import 'package:app_flutter/features/dashboard/repositories/dashboard_repository.dart';
import 'package:app_flutter/models/dashboard/notification_banner.dart';
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

  group('NotificationBanner.fromJson', () {
    test('lee id y mensaje ya resueltos por el backend', () {
      final banner = NotificationBanner.fromJson(const {
        'id': 'banner-1',
        'message': 'Mantenimiento el domingo',
      });

      expect(banner.id, 'banner-1');
      expect(banner.message, 'Mantenimiento el domingo');
    });

    test('sustituye por cadena vacía los campos ausentes o nulos', () {
      final vacio = NotificationBanner.fromJson(const {});
      expect(vacio.id, isEmpty);
      expect(vacio.message, isEmpty);

      final nulos = NotificationBanner.fromJson(const {
        'id': null,
        'message': null,
      });
      expect(nulos.id, isEmpty);
      expect(nulos.message, isEmpty);
    });

    // El backend guarda el mensaje como mapa por idioma y solo lo aplana en
    // /active; si alguna vez sirviera el mapa crudo, el modelo no debe
    // reventar con un CastError en mitad del dashboard.
    test('tolera tipos que no son String sin lanzar', () {
      final numerico = NotificationBanner.fromJson(const {
        'id': 7,
        'message': 42,
      });
      expect(numerico.id, '7');
      expect(numerico.message, '42');

      final mapa = NotificationBanner.fromJson(const {
        'id': 'banner-1',
        'message': {'es': 'Hola'},
      });
      expect(mapa.message, contains('es'));
    });
  });

  group('AdminRepository: rutas de banners', () {
    test('las cuatro operaciones usan método y ruta esperados', () async {
      final calls = <String>[];
      final bodies = <String>[];
      final mock = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        bodies.add(request.body);
        if (request.method == 'GET') {
          return _json([
            {'id': 'banner-1'},
          ]);
        }
        if (request.method == 'DELETE') return http.Response('', 204);
        return _json({'id': 'banner-1'});
      });
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);
      final repository = AdminRepository(apiClient: client);

      await repository.listNotificationBanners('token');
      await repository.createNotificationBanner('token', {'message': 'hola'});
      await repository.updateNotificationBanner('token', 'banner-1', {
        'message': 'adios',
      });
      await repository.deleteNotificationBanner('token', 'banner-1');

      expect(calls, [
        'GET /api/settings/notification-banners',
        'POST /api/settings/notification-banners',
        'PUT /api/settings/notification-banners/banner-1',
        'DELETE /api/settings/notification-banners/banner-1',
      ]);
      expect(jsonDecode(bodies[1]), {'message': 'hola'});
      expect(jsonDecode(bodies[2]), {'message': 'adios'});
    });

    // El id viaja en el path: sin codificar, un id con barra o espacio
    // apuntaría a otra ruta (o a ninguna) y el borrado fallaría en silencio.
    test('codifica el id del banner en la ruta', () async {
      String? path;
      final mock = MockClient((request) async {
        path = request.url.path;
        return http.Response('', 204);
      });
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);

      await AdminRepository(
        apiClient: client,
      ).deleteNotificationBanner('token', 'a/b c');

      expect(path, '/api/settings/notification-banners/a%2Fb%20c');
    });

    test('devuelve lista vacía si el listado no es un array', () async {
      final mock = MockClient((_) async => _json({'detail': 'nope'}));
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);

      final banners = await AdminRepository(
        apiClient: client,
      ).listNotificationBanners('token');

      expect(banners, isEmpty);
    });

    test('descarta del listado los elementos que no son objetos', () async {
      final mock = MockClient(
        (_) async => _json([
          {'id': 'banner-1'},
          'basura',
          null,
        ]),
      );
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);

      final banners = await AdminRepository(
        apiClient: client,
      ).listNotificationBanners('token');

      expect(banners.map((banner) => banner['id']), ['banner-1']);
    });
  });

  group('DashboardRepository.getActiveBanners', () {
    test('pide /active y mapea al modelo', () async {
      String? path;
      final mock = MockClient((request) async {
        path = request.url.path;
        return _json([
          {'id': 'banner-1', 'message': 'Aviso'},
        ]);
      });
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);

      final banners = await DashboardRepository(
        client,
      ).getActiveBanners('token');

      expect(path, '/api/settings/notification-banners/active');
      expect(banners.single.id, 'banner-1');
      expect(banners.single.message, 'Aviso');
    });

    // Un banner es un aviso informativo: si su endpoint falla no puede
    // tumbar el dashboard entero, así que _safeList traga el error a
    // propósito. Esto congela ese comportamiento, no lo cuestiona.
    test(
      'devuelve vacío ante un error del servidor en vez de propagarlo',
      () async {
        final mock = MockClient(
          (_) async => _json({'detail': 'boom'}, status: 500),
        );
        final client = ApiClient(backendController, client: mock);
        addTearDown(client.close);

        await expectLater(
          DashboardRepository(client).getActiveBanners('token'),
          completion(isEmpty),
        );
      },
    );

    test('devuelve vacío si la red no responde', () async {
      final mock = MockClient((_) async => throw const SocketFailure());
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);

      await expectLater(
        DashboardRepository(client).getActiveBanners('token'),
        completion(isEmpty),
      );
    });

    test('acepta también la envoltura {"data": [...]}', () async {
      final mock = MockClient(
        (_) async => _json({
          'data': [
            {'id': 'banner-1', 'message': 'Aviso'},
          ],
        }),
      );
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);

      final banners = await DashboardRepository(
        client,
      ).getActiveBanners('token');

      expect(banners.single.id, 'banner-1');
    });
  });
}

http.Response _json(Object? body, {int status = 200}) {
  return http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );
}

/// Fallo de red sin respuesta HTTP, que es lo que distingue "backend caído"
/// de "backend devolvió 500" en [ApiClient].
class SocketFailure implements Exception {
  const SocketFailure();
}
