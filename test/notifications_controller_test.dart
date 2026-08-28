import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/manager/repositories/manager_repository.dart';
import 'package:app_flutter/features/notifications/controllers/notifications_controller.dart';
import 'package:app_flutter/features/notifications/repositories/notifications_repository.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

Map<String, dynamic> _aviso({bool read = false}) => {
  'id': 'n-1',
  'kind': 'group_invite',
  'data': {'actor': 'ana', 'group': 'Marketing', 'invitation_id': 'inv-1'},
  'read': read,
  'created_at': '2026-01-01T00:00:00Z',
};

/// Controller listo con un backend simulado. [responder] decide cada respuesta.
Future<({NotificationsController controller, List<String> peticiones})> _montar(
  http.Response Function(http.Request request) responder, {
  String rol = 'user',
}) async {
  SharedPreferences.setMockInitialValues({});
  final backend = await BackendController.bootstrap();
  final session = await SessionController.bootstrap(
    secureStore: MemorySecureStore(),
  );
  await session.login(
    token: 'token',
    user: SessionUser(username: 'bea', role: rol),
    remember: false,
  );

  final peticiones = <String>[];
  final client = ApiClient(
    backend,
    client: MockClient((request) async {
      peticiones.add('${request.method} ${request.url.path}');
      return responder(request);
    }),
  );
  final controller = NotificationsController(
    repository: NotificationsRepository(apiClient: client),
    manager: ManagerRepository(apiClient: client),
    session: session,
  );
  addTearDown(controller.dispose);
  addTearDown(client.close);
  return (controller: controller, peticiones: peticiones);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las categorías salen del servidor, no de una lista propia', () async {
    // Si el cliente llevara su copia, añadir un evento en el backend dejaría
    // aquí un interruptor que falta y nadie lo notaría.
    final montaje = await _montar(
      (_) => http.Response(
        jsonEncode({
          'notify_email': true,
          'notify_push': true,
          'notification_categories': {
            'groups': {'email': true, 'push': false},
            'inventada_por_el_servidor': {'email': false, 'push': true},
          },
        }),
        200,
      ),
    );

    await montaje.controller.cargarPreferencias();

    expect(montaje.controller.categorias.keys, contains('groups'));
    expect(
      montaje.controller.categorias.keys,
      contains('inventada_por_el_servidor'),
      reason: 'debe pintar lo que reciba, sin filtrar por una lista propia',
    );
    expect(montaje.controller.categorias['groups']!['push'], isFalse);
  });

  test('cambiar un interruptor se queda con lo que devuelve el servidor', () async {
    final montaje = await _montar((request) {
      if (request.method == 'PUT') {
        return http.Response(
          jsonEncode({
            'notification_categories': {
              'groups': {'email': false, 'push': true},
            },
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'notification_categories': {}}), 200);
    });

    await montaje.controller.cambiarCategoria('groups', 'email', false);

    expect(montaje.controller.categorias['groups']!['email'], isFalse);
    expect(montaje.peticiones, contains('PUT /api/settings'));
  });

  test('fuera de web no se ofrece el push', () async {
    // La suite corre en la VM, donde el stub responde «no soportado». Es el
    // mismo camino que toman Android e iOS nativos hasta que se publiquen las
    // apps y entren FCM y APNs: la interfaz no debe enseñar el interruptor.
    final montaje = await _montar(
      (_) => http.Response(
        jsonEncode({'key': 'clave-vapid', 'enabled': true}),
        200,
      ),
    );

    await montaje.controller.cargarEstadoPush();

    expect(montaje.controller.puedeOfrecerPush, isFalse);
    expect(montaje.controller.requiereInstalarEnIOS, isFalse);
  });

  test('activar el push fuera de web no llama al backend', () async {
    final montaje = await _montar(
      (_) => http.Response(jsonEncode({'ok': true}), 200),
    );

    final estado = await montaje.controller.activarPush();

    expect(estado.name, 'noSoportado');
    expect(
      montaje.peticiones.where((p) => p.contains('push/subscribe')),
      isEmpty,
    );
  });

  test('carga la lista y el contador', () async {
    final montaje = await _montar(
      (_) => http.Response(
        jsonEncode({
          'items': [_aviso()],
          'unread': 1,
        }),
        200,
      ),
    );

    await montaje.controller.load();

    expect(montaje.controller.unread, 1);
    expect(montaje.controller.items.single['kind'], 'group_invite');
  });

  test('marcar leído baja el contador y marca la fila', () async {
    final montaje = await _montar((request) {
      if (request.url.path == '/api/notifications/read') {
        return http.Response(jsonEncode({'ok': true, 'unread': 0}), 200);
      }
      return http.Response(
        jsonEncode({
          'items': [_aviso()],
          'unread': 1,
        }),
        200,
      );
    });

    await montaje.controller.load();
    await montaje.controller.markRead('n-1');

    expect(montaje.controller.unread, 0);
    expect(montaje.controller.items.single['read'], true);
  });

  test('aceptar llama al endpoint de la invitación y deja el aviso leído', () async {
    final montaje = await _montar((request) {
      if (request.url.path.endsWith('/accept')) {
        return http.Response(jsonEncode({'ok': true}), 200);
      }
      if (request.url.path == '/api/notifications/read') {
        return http.Response(jsonEncode({'ok': true, 'unread': 0}), 200);
      }
      return http.Response(jsonEncode({'items': <Object>[], 'unread': 0}), 200);
    });

    await montaje.controller.accept('n-1', 'inv-1');

    expect(
      montaje.peticiones,
      contains('POST /api/groups/invitations/inv-1/accept'),
    );
    expect(montaje.peticiones, contains('POST /api/notifications/read'));
    expect(montaje.controller.unread, 0);
  });

  test('una invitación ya cancelada (404) no revienta y se marca leída', () async {
    // Es la carrera real: la invitación se cancela entre el sondeo y el clic.
    final montaje = await _montar((request) {
      if (request.url.path.endsWith('/accept')) {
        return http.Response(
          jsonEncode({
            'detail': {'code': 'not_found', 'message': 'no está'},
          }),
          404,
        );
      }
      if (request.url.path == '/api/notifications/read') {
        return http.Response(jsonEncode({'ok': true, 'unread': 0}), 200);
      }
      return http.Response(jsonEncode({'items': <Object>[], 'unread': 0}), 200);
    });

    await montaje.controller.accept('n-1', 'inv-1');

    expect(montaje.peticiones, contains('POST /api/notifications/read'));
    expect(montaje.controller.unread, 0);
  });

  test('el invitado no sondea: la campana no existe para él', () async {
    // El endpoint usa `require_auth` y le respondería 403 cada 60 segundos.
    final montaje = await _montar(
      (_) => http.Response(jsonEncode({'items': <Object>[], 'unread': 0}), 200),
      rol: 'guest',
    );

    await montaje.controller.load();

    expect(montaje.controller.enabled, isFalse);
    expect(montaje.peticiones, isEmpty);
  });

  test('un backend sin la ruta no rompe la campana', () async {
    // El orden de despliegue es backend primero, pero si alguien sirve una app
    // nueva contra un backend viejo el shell no puede caerse por esto.
    final montaje = await _montar((_) => http.Response('not found', 404));

    await montaje.controller.load();

    expect(montaje.controller.unread, 0);
    expect(montaje.controller.items, isEmpty);
  });
}
