import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/explore/controllers/explore_controller.dart';
import 'package:app_flutter/features/explore/repositories/explore_repository.dart';
import 'package:app_flutter/features/manager/repositories/manager_repository.dart';
import 'package:app_flutter/models/explore/explore_models.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/i18n_de_prueba.dart';
import '../../support/memory_secure_store.dart';

/// Devuelve el fallback tal cual: el controller no debe depender de que
/// haya locales cargados para producir sus mensajes.

Map<String, dynamic> _resource({
  String type = 'agent',
  String id = 'a1',
  String name = 'Agente A',
  String category = 'Coding',
  int stars = 3,
}) => {
  'resource_type': type,
  'resource_id': id,
  'owner_username': 'bob',
  'name': name,
  'category': category,
  'stars_count': stars,
};

void main() {
  setUp(cargarTraduccionesDePrueba);

  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  /// Sesión con token, o sin él si [token] es `null`.
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
  });

  /// Monta el controller sobre un [MockClient] y lo cierra al terminar.
  Future<ExploreController> build(
    Future<http.Response> Function(http.Request request) handler, {
    String? token = 'token',
  }) async {
    final client = ApiClient(backendController, client: MockClient(handler));
    addTearDown(client.close);
    final controller = ExploreController(
      repository: ExploreRepository(apiClient: client),
      managerRepository: ManagerRepository(apiClient: client),
      sessionController: await session(token: token),
      tx: tr,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('load publica los resultados y manda los filtros activos', () async {
    Uri? seen;
    final controller = await build((request) async {
      seen = request.url;
      return http.Response(jsonEncode([_resource()]), 200);
    });

    controller.queryController.text = 'agente';
    await controller.setType('agent');
    await controller.setLabels({'draft'});
    await controller.setLanguages({'es'});

    expect(controller.loading, isFalse);
    expect(controller.error, isNull);
    expect(controller.items.single.resourceId, 'a1');
    expect(seen?.queryParameters['type'], 'agent');
    expect(seen?.queryParameters['q'], 'agente');
    expect(seen?.queryParametersAll['label'], ['draft']);
    expect(seen?.queryParametersAll['language'], ['es']);
    // El botón secundario cuenta labels/categoría; el tipo vive en la barra.
    expect(controller.secondaryActiveFilterCount, 2);
  });

  test('load sin sesión avisa en vez de llamar a la API', () async {
    var calls = 0;
    final controller = await build((request) async {
      calls++;
      return http.Response('[]', 200);
    }, token: null);

    await controller.load();

    expect(calls, 0);
    expect(controller.loading, isFalse);
    expect(controller.error, 'No hay sesión activa');
  });

  test('load descarta una categoría que ya no existe en los datos', () async {
    final controller = await build(
      (request) async =>
          http.Response(jsonEncode([_resource(category: 'Writing')]), 200),
    );

    await controller.setCategory('Coding');

    expect(controller.category, '');
    expect(controller.categoryOptions, ['Writing']);
  });

  test('load ignora una respuesta anterior que termina más tarde', () async {
    final oldStarted = Completer<void>();
    final releaseOld = Completer<void>();
    final controller = await build((request) async {
      if (request.url.path.endsWith('/official-packs')) {
        return http.Response('[]', 200);
      }
      final query = request.url.queryParameters['q'];
      if (query == 'old') {
        oldStarted.complete();
        await releaseOld.future;
        return http.Response(jsonEncode([_resource(id: 'old')]), 200);
      }
      if (query == 'new') {
        return http.Response(jsonEncode([_resource(id: 'new')]), 200);
      }
      return http.Response('[]', 200);
    });
    await controller.setOfficialPacksMode(false);

    controller.queryController.text = 'old';
    final oldLoad = controller.load();
    await oldStarted.future;
    controller.queryController.text = 'new';
    await controller.load();
    releaseOld.complete();
    await oldLoad;

    expect(controller.items.single.resourceId, 'new');
    expect(controller.loading, isFalse);
  });

  test(
    'Explore no conserva una respuesta que otro usuario puede cambiar',
    () async {
      var resourceCalls = 0;
      final controller = await build((request) async {
        if (request.url.path.endsWith('/official-packs')) {
          return http.Response('[]', 200);
        }
        resourceCalls++;
        return http.Response(
          jsonEncode([_resource(id: 'a$resourceCalls')]),
          200,
        );
      });

      await controller.load();
      await controller.load();

      expect(resourceCalls, 2);
      expect(controller.items.single.resourceId, 'a2');
    },
  );

  test('carga las páginas posteriores del catálogo de recursos', () async {
    final controller = await build((request) async {
      if (request.url.path.endsWith('/official-packs')) {
        return http.Response('[]', 200);
      }
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      final count = offset == 0 ? 40 : 1;
      return http.Response(
        jsonEncode([
          for (var index = 0; index < count; index++)
            _resource(id: 'agent-${offset + index}'),
        ]),
        200,
        headers: {'x-total-count': '41'},
      );
    });

    await controller.load();
    expect(controller.items, hasLength(40));
    expect(controller.resourcesHasMore, isTrue);

    await controller.loadMoreResources();
    expect(controller.items, hasLength(41));
    expect(controller.items.last.resourceId, 'agent-40');
    expect(controller.resourcesHasMore, isFalse);
  });

  test('clearFilters deja el filtro en su estado inicial', () async {
    final controller = await build(
      (request) async => http.Response(jsonEncode([_resource()]), 200),
    );

    await controller.setType('skill');
    await controller.toggleLabel('draft', selected: true);
    await controller.toggleLanguage('es', selected: true);
    await controller.clearFilters();

    expect(controller.type, 'all');
    expect(controller.category, '');
    expect(controller.hasLabel('draft'), isFalse);
    expect(controller.hasLanguage('es'), isFalse);
    expect(controller.secondaryActiveFilterCount, 0);
  });

  test('clearSecondaryFilters conserva el tipo visible', () async {
    final controller = await build(
      (request) async => http.Response(jsonEncode([_resource()]), 200),
    );

    await controller.setType('skill');
    await controller.toggleLabel('draft', selected: true);
    await controller.toggleLanguage('en', selected: true);
    await controller.clearSecondaryFilters();

    expect(controller.type, 'skill');
    expect(controller.category, '');
    expect(controller.hasLabel('draft'), isFalse);
    expect(controller.hasLanguage('en'), isFalse);
    expect(controller.secondaryActiveFilterCount, 0);
  });

  test('agrupa cambios rápidos de filtros en una sola carga', () async {
    var exploreCalls = 0;
    final controller = await build((request) async {
      if (request.url.path == '/api/explore') exploreCalls++;
      return http.Response('[]', 200);
    });

    final first = controller.toggleLabel('draft', selected: true);
    final second = controller.toggleLanguage('es', selected: true);
    await Future.wait([first, second]);

    expect(exploreCalls, 1);
    expect(controller.hasLabel('draft'), isTrue);
    expect(controller.hasLanguage('es'), isTrue);
  });

  test(
    'clearExploreFilters restaura la agrupación oficial por packs',
    () async {
      final controller = await build(
        (request) async => http.Response(jsonEncode([]), 200),
      );

      await controller.setOfficialPacksMode(false);
      await controller.toggleLabel('draft', selected: true);
      await controller.clearExploreFilters();

      expect(controller.officialPacksMode, isTrue);
      expect(controller.hasLabel('draft'), isFalse);
      expect(controller.secondaryActiveFilterCount, 0);
    },
  );

  test('toggleStar alterna el estado y refleja el contador nuevo', () async {
    final controller = await build((request) async {
      if (request.url.path.endsWith('/star')) {
        return http.Response(jsonEncode({'stars': 4}), 200);
      }
      return http.Response(jsonEncode([_resource()]), 200);
    });
    await controller.load();
    final item = controller.items.single;

    final added = await controller.toggleStar(item);
    expect(added?.message, 'Añadido a favoritos');
    expect(added?.isError, isFalse);
    expect(controller.isStarred(item), isTrue);
    expect(controller.items.single.stars, 4);

    final removed = await controller.toggleStar(item);
    expect(removed?.message, 'Quitado de favoritos');
    expect(controller.isStarred(item), isFalse);
  });

  test('link nombra el recurso enlazado y no lo enlaza dos veces', () async {
    var links = 0;
    final controller = await build((request) async {
      if (request.url.path.endsWith('/link')) {
        links++;
        return http.Response(jsonEncode({'name': 'Copia de Agente A'}), 200);
      }
      return http.Response(jsonEncode([_resource()]), 200);
    });
    await controller.load();
    final item = controller.items.single;

    final first = await controller.link(item);
    expect(first?.message, 'Recurso enlazado: Copia de Agente A');
    expect(controller.isLinked(item), isTrue);

    expect(await controller.link(item), isNull);
    expect(links, 1);
  });

  test('link informa del error del backend sin marcar el recurso', () async {
    final controller = await build((request) async {
      if (request.url.path.endsWith('/link')) {
        return http.Response(jsonEncode({'detail': 'Cuota agotada'}), 402);
      }
      return http.Response(jsonEncode([_resource()]), 200);
    });
    await controller.load();
    final item = controller.items.single;

    final result = await controller.link(item);

    expect(result?.isError, isTrue);
    expect(result?.message, contains('Cuota agotada'));
    expect(controller.isLinked(item), isFalse);
    expect(controller.isBusy(item), isFalse);
  });

  test('preview mantiene el recurso ocupado mientras se muestra', () async {
    final controller = await build((request) async {
      if (request.url.path.endsWith('/preview')) {
        return http.Response(jsonEncode({'name': 'Agente A'}), 200);
      }
      return http.Response(jsonEncode([_resource()]), 200);
    });
    await controller.load();
    final item = controller.items.single;

    late bool busyWhileShown;
    Map<String, dynamic>? shown;
    final result = await controller.preview(
      item,
      present: (payload) async {
        shown = payload;
        busyWhileShown = controller.isBusy(item);
      },
    );

    expect(result, isNull);
    expect(shown?['name'], 'Agente A');
    expect(busyWhileShown, isTrue);
    expect(controller.isBusy(item), isFalse);
  });

  test('carga y presenta el grafo público de un recurso', () async {
    final controller = await build((request) async {
      if (request.url.path.endsWith('/relations')) {
        return http.Response(
          jsonEncode({
            'root': {'type': 'agent', 'id': 'a1', 'label': 'Agente A'},
            'items': [
              {
                'type': 'skill',
                'id': 's1',
                'label': 'Skill A',
                'relation': 'uses',
                'via': null,
              },
            ],
          }),
          200,
        );
      }
      return http.Response(jsonEncode([_resource()]), 200);
    });
    await controller.load();
    final item = controller.items.single;

    late bool busyWhileShown;
    String? shownRoot;
    final result = await controller.showResourceGraph(
      item,
      present: (graph) async {
        shownRoot = graph.rootId;
        busyWhileShown = controller.isBusy(item);
      },
    );

    expect(result, isNull);
    expect(shownRoot, 'agent:a1');
    expect(busyWhileShown, isTrue);
    expect(controller.isBusy(item), isFalse);
  });

  test('carga y presenta el grafo de un pack oficial', () async {
    final controller = await build((request) async {
      if (request.url.path.endsWith('/relations')) {
        return http.Response(
          jsonEncode({
            'root': {
              'type': 'official_source',
              'id': 'source-1',
              'label': 'Pack',
            },
            'items': <Map<String, dynamic>>[],
          }),
          200,
        );
      }
      return http.Response('[]', 200);
    });
    const pack = ExploreOfficialPack(
      sourceId: 'source-1',
      name: 'Pack',
      repositoryUrl: 'https://github.com/example/pack',
      counts: {'agent': 1},
    );

    String? shownRoot;
    final result = await controller.showOfficialPackGraph(
      pack,
      present: (graph) async {
        shownRoot = graph.rootId;
        expect(controller.isPackBusy(pack), isTrue);
      },
    );

    expect(result, isNull);
    expect(shownRoot, 'official_source:source-1');
    expect(controller.isPackBusy(pack), isFalse);
  });

  test('loadMoreUsers acumula la página siguiente', () async {
    final pages = <int, List<Map<String, dynamic>>>{
      0: List.generate(
        ExploreController.usersPageSize,
        (index) => {'username': 'user$index'},
      ),
      ExploreController.usersPageSize: [
        {'username': 'ultimo'},
      ],
    };
    final controller = await build((request) async {
      final offset = int.parse(request.url.queryParameters['offset'] ?? '0');
      return http.Response(jsonEncode(pages[offset] ?? []), 200);
    });

    await controller.loadUsers();
    expect(controller.users.length, ExploreController.usersPageSize);
    expect(controller.usersHasMore, isTrue);

    expect(await controller.loadMoreUsers(), isNull);
    expect(controller.users.length, ExploreController.usersPageSize + 1);
    expect(controller.users.last.username, 'ultimo');
    expect(controller.usersHasMore, isFalse);

    // Sin más páginas, la acción es un no-op.
    expect(await controller.loadMoreUsers(), isNull);
    expect(controller.users.length, ExploreController.usersPageSize + 1);
  });

  test('inviteUser exige un grupo de equipo activo', () async {
    var invites = 0;
    final controller = await build((request) async {
      if (request.url.path.contains('/invitations')) {
        invites++;
        return http.Response('{}', 200);
      }
      return http.Response(
        jsonEncode([
          {'id': 'g1', 'type': 'personal', 'active': true},
        ]),
        200,
      );
    });

    final result = await controller.inviteUser('carol');

    expect(result?.isError, isTrue);
    expect(result?.message, 'Activa un grupo de equipo para invitar usuarios');
    expect(invites, 0);
    expect(controller.isInviting('carol'), isFalse);
  });

  test('inviteUser manda la invitación al grupo activo', () async {
    String? invitedPath;
    final controller = await build((request) async {
      if (request.url.path.contains('/invitations')) {
        invitedPath = request.url.path;
        return http.Response('{}', 200);
      }
      return http.Response(
        jsonEncode([
          {'id': 'g0', 'type': 'team', 'active': false},
          {'id': 'g1', 'type': 'team', 'active': true},
        ]),
        200,
      );
    });

    final result = await controller.inviteUser('carol');

    expect(result?.isError, isFalse);
    expect(result?.message, 'Invitación enviada a carol');
    expect(invitedPath, '/api/groups/g1/invitations');
  });

  test('notifica a sus oyentes en cada transición de carga', () async {
    final controller = await build(
      (request) async => http.Response(jsonEncode([_resource()]), 200),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    await controller.load();

    // Una al entrar en "cargando" y otra al publicar el resultado.
    expect(notifications, 2);
  });

  test('no notifica después de dispose', () async {
    final client = ApiClient(
      backendController,
      client: MockClient(
        (_) async => http.Response(jsonEncode([_resource()]), 200),
      ),
    );
    addTearDown(client.close);
    final controller = ExploreController(
      repository: ExploreRepository(apiClient: client),
      managerRepository: ManagerRepository(apiClient: client),
      sessionController: await session(),
      tx: tr,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    final pending = controller.load();
    controller.dispose();
    await pending;

    // La notificación de "cargando" llegó antes del dispose; ninguna después.
    expect(notifications, 1);
  });

  test('expone los items sin copiarlos en cada lectura', () async {
    final controller = await build(
      (request) async => http.Response(
        jsonEncode([_resource(), _resource(id: 'a2', name: 'Agente B')]),
        200,
      ),
    );
    await controller.load();

    expect(identical(controller.items, controller.items), isTrue);
    expect(controller.itemKey(controller.items.last), 'agent:a2');
  });
}
