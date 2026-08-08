import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/manager/controllers/manager_controller.dart';
import 'package:app_flutter/features/manager/repositories/manager_repository.dart';
import 'package:app_flutter/models/manager/group_models.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/memory_secure_store.dart';

/// Devuelve el fallback tal cual: el controller no debe depender de que
/// haya locales cargados para producir sus mensajes.
String _tx(String path, String fallback) => fallback;

Map<String, dynamic> _group({
  String id = 'g1',
  String name = 'Equipo',
  String type = 'team',
  String role = 'owner',
  bool active = true,
}) => {
  'id': id,
  'name': name,
  'type': type,
  'role': role,
  'active': active,
};

GroupItem _item({
  String id = 'g1',
  String name = 'Equipo',
  String type = 'team',
  bool active = false,
}) => GroupItem(raw: _group(id: id, name: name, type: type, active: active));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
  });

  Future<SessionController> session({String? token = 'token'}) {
    SharedPreferences.setMockInitialValues(
      token == null
          ? {}
          : {
              'ga_token': token,
              'session_username': 'alice',
              'session_role': 'user',
            },
    );
    return SessionController.bootstrap(secureStore: MemorySecureStore());
  }

  /// Respuestas por defecto del listado: un grupo de equipo activo con un
  /// miembro y una invitación pendiente.
  http.Response listResponse(
    http.BaseRequest request, {
    List<Map<String, dynamic>>? groups,
  }) {
    final path = request.url.path;
    if (path == '/api/groups') {
      return http.Response(jsonEncode(groups ?? [_group()]), 200);
    }
    if (path.endsWith('/members')) {
      return http.Response(
        jsonEncode([
          {'username': 'bob', 'role': 'member'},
        ]),
        200,
      );
    }
    if (path.endsWith('/invitations')) {
      return http.Response(
        jsonEncode([
          {'id': 'i1', 'username': 'carol', 'created_at': '2026-08-01'},
        ]),
        200,
      );
    }
    return http.Response('{}', 200);
  }

  /// Monta el controller sobre un [MockClient] y lo cierra al terminar.
  Future<ManagerController> build(
    Future<http.Response> Function(http.Request request) handler, {
    String? token = 'token',
    SessionController? sessionController,
  }) async {
    final client = ApiClient(backendController, client: MockClient(handler));
    addTearDown(client.close);
    final controller = ManagerController(
      repository: ManagerRepository(apiClient: client),
      sessionController: sessionController ?? await session(token: token),
      tx: _tx,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  /// `askName` que responde siempre lo mismo, sin abrir ningún diálogo.
  Future<String?> Function() answers(String? value) => () async => value;

  test('load trae grupos, miembros e invitaciones del grupo activo', () async {
    final controller = await build((request) async => listResponse(request));

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.error, isNull);
    expect(controller.groups.single.id, 'g1');
    expect(controller.activeGroup?.name, 'Equipo');
    expect(controller.canManageMembers, isTrue);
    expect(controller.members.single['username'], 'bob');
    expect(controller.invitations.single['id'], 'i1');
  });

  test('load sin sesión avisa en vez de llamar a la API', () async {
    var calls = 0;
    final controller = await build((request) async {
      calls++;
      return listResponse(request);
    }, token: null);

    await controller.load();

    expect(calls, 0);
    expect(controller.error, 'No hay sesión activa');
    expect(controller.groups, isEmpty);
  });

  test('el detalle que falla no tumba el listado de grupos', () async {
    final controller = await build((request) async {
      final path = request.url.path;
      if (path.endsWith('/members') || path.endsWith('/invitations')) {
        return http.Response(jsonEncode({'detail': 'Sin permiso'}), 403);
      }
      return listResponse(request);
    });

    await controller.load();

    expect(controller.error, isNull);
    expect(controller.groups, hasLength(1));
    expect(controller.members, isEmpty);
    expect(controller.invitations, isEmpty);
  });

  test('sin grupo activo no se piden miembros ni invitaciones', () async {
    var detailCalls = 0;
    final controller = await build((request) async {
      final path = request.url.path;
      if (path.endsWith('/members') || path.endsWith('/invitations')) {
        detailCalls++;
      }
      return listResponse(request, groups: [_group(active: false)]);
    });

    await controller.load();

    expect(detailCalls, 0);
    expect(controller.activeGroup, isNull);
    expect(controller.canManageMembers, isFalse);
  });

  test('createGroup no llama a la API si se cancela el diálogo', () async {
    var posts = 0;
    final controller = await build((request) async {
      if (request.method == 'POST') posts++;
      return listResponse(request);
    });
    await controller.load();

    final result = await controller.createGroup(askName: answers(null));

    expect(result, isNull);
    expect(posts, 0);
  });

  test('createGroup manda el nombre y recarga', () async {
    String? sentName;
    var groupCalls = 0;
    final controller = await build((request) async {
      if (request.method == 'POST' && request.url.path == '/api/groups') {
        sentName =
            (jsonDecode(request.body) as Map<String, dynamic>)['name']
                as String?;
        return http.Response('{}', 200);
      }
      if (request.url.path == '/api/groups') groupCalls++;
      return listResponse(request);
    });
    await controller.load();
    final before = groupCalls;

    final result = await controller.createGroup(askName: answers('Equipo B'));

    expect(result?.isError, isFalse);
    expect(result?.message, 'Grupo creado');
    expect(sentName, 'Equipo B');
    // La mutación invalida la caché, así que la recarga vuelve a preguntar.
    expect(groupCalls, greaterThan(before));
  });

  test('el grupo Personal no se renombra ni se elimina', () async {
    var mutations = 0;
    final controller = await build((request) async {
      if (request.method != 'GET') mutations++;
      return listResponse(request);
    });
    await controller.load();
    final personal = _item(id: 'p1', name: 'Personal', type: 'personal');

    final renamed = await controller.renameGroup(
      personal,
      askName: (_) async => 'Otro',
    );
    final deleted = await controller.deleteGroup(
      personal,
      confirm: () async => true,
    );

    // Son avisos, no errores: la acción simplemente no aplica.
    expect(renamed?.isError, isFalse);
    expect(renamed?.message, 'El grupo Personal no se puede renombrar');
    expect(deleted?.message, 'El grupo Personal no se puede eliminar');
    expect(mutations, 0);
  });

  test('deleteGroup respeta la confirmación denegada', () async {
    var deletes = 0;
    final controller = await build((request) async {
      if (request.method == 'DELETE') deletes++;
      return listResponse(request);
    });
    await controller.load();

    final result = await controller.deleteGroup(
      _item(),
      confirm: () async => false,
    );

    expect(result, isNull);
    expect(deletes, 0);
  });

  test('renameGroup informa del error del backend', () async {
    final controller = await build((request) async {
      if (request.method == 'PATCH') {
        return http.Response(jsonEncode({'detail': 'Nombre repetido'}), 409);
      }
      return listResponse(request);
    });
    await controller.load();

    final result = await controller.renameGroup(
      _item(),
      askName: (_) async => 'Equipo B',
    );

    expect(result?.isError, isTrue);
    expect(result?.message, contains('Nombre repetido'));
  });

  test('switchGroup renueva la sesión con el token que devuelve', () async {
    final sessionController = await session();
    final controller = await build((request) async {
      if (request.url.path.startsWith('/api/groups/switch/')) {
        return http.Response(
          '{}',
          200,
          headers: {'set-cookie': 'ga_token=token-nuevo; Path=/; HttpOnly'},
        );
      }
      return listResponse(request);
    }, sessionController: sessionController);
    await controller.load();

    final result = await controller.switchGroup(_item(id: 'g2', name: 'Otro'));

    expect(result?.isError, isFalse);
    expect(result?.message, 'Grupo activo cambiado a Otro');
    expect(sessionController.gaToken, 'token-nuevo');
    expect(controller.isSwitching(_item(id: 'g2')), isFalse);
  });

  test('switchGroup no hace nada sobre el grupo ya activo', () async {
    var switches = 0;
    final controller = await build((request) async {
      if (request.url.path.startsWith('/api/groups/switch/')) switches++;
      return listResponse(request);
    });
    await controller.load();

    final result = await controller.switchGroup(
      GroupItem(raw: _group(active: true)),
    );

    expect(result, isNull);
    expect(switches, 0);
  });

  test('invitar y añadir miembros exige un grupo compartido', () async {
    var mutations = 0;
    final controller = await build((request) async {
      if (request.method != 'GET') mutations++;
      return listResponse(
        request,
        groups: [_group(id: 'p1', name: 'Personal', type: 'personal')],
      );
    });
    await controller.load();
    expect(controller.canManageMembers, isFalse);

    final invited = await controller.inviteMember(askName: answers('bob'));
    final added = await controller.addMemberDirect(askName: answers('bob'));

    expect(invited?.isError, isTrue);
    expect(invited?.message, 'Activa un grupo compartido para invitar miembros');
    expect(added?.isError, isTrue);
    expect(added?.message, 'Activa un grupo compartido para añadir miembros');
    expect(mutations, 0);
  });

  test('el nombre de usuario se normaliza antes de enviarlo', () async {
    final sent = <String, String>{};
    final controller = await build((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/members')) {
        sent['add'] =
            (jsonDecode(request.body) as Map<String, dynamic>)['username']
                as String;
        return http.Response('{}', 200);
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/invitations')) {
        sent['invite'] =
            (jsonDecode(request.body) as Map<String, dynamic>)['username']
                as String;
        return http.Response('{}', 200);
      }
      return listResponse(request);
    });
    await controller.load();

    await controller.inviteMember(askName: answers('  BOB  '));
    await controller.addMemberDirect(askName: answers(' Carol '));

    expect(sent['invite'], 'bob');
    expect(sent['add'], 'carol');
  });

  test('removeMember y cancelInvitation apuntan al grupo activo', () async {
    final deleted = <String>[];
    final controller = await build((request) async {
      if (request.method == 'DELETE') {
        deleted.add(request.url.path);
        return http.Response('{}', 200);
      }
      return listResponse(request);
    });
    await controller.load();

    final removed = await controller.removeMember('bob');
    final cancelled = await controller.cancelInvitation('i1');

    expect(removed?.message, 'Miembro eliminado');
    expect(cancelled?.message, 'Invitación cancelada');
    expect(deleted, [
      '/api/groups/g1/members/bob',
      '/api/groups/g1/invitations/i1',
    ]);
  });

  test('sin grupo compartido no se borran miembros ni invitaciones', () async {
    var deletes = 0;
    final controller = await build((request) async {
      if (request.method == 'DELETE') deletes++;
      return listResponse(
        request,
        groups: [_group(id: 'p1', name: 'Personal', type: 'personal')],
      );
    });
    await controller.load();

    expect(await controller.removeMember('bob'), isNull);
    expect(await controller.cancelInvitation('i1'), isNull);
    expect(deletes, 0);
  });

  test('no notifica después de dispose', () async {
    final client = ApiClient(
      backendController,
      client: MockClient((request) async => listResponse(request)),
    );
    addTearDown(client.close);
    final controller = ManagerController(
      repository: ManagerRepository(apiClient: client),
      sessionController: await session(),
      tx: _tx,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    final pending = controller.load();
    controller.dispose();
    await pending;

    // La notificación de "cargando" llegó antes del dispose; ninguna después.
    expect(notifications, 1);
  });
}
