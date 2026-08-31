import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/connections/controllers/connections_controller.dart';
import 'package:app_flutter/features/connections/repositories/connections_repository.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/i18n_de_prueba.dart';
import '../../support/memory_secure_store.dart';

Map<String, dynamic> _connection({
  String id = 'c1',
  String name = 'OpenAI principal',
  String type = 'openai',
  String model = 'gpt-5',
  bool active = true,
}) => {
  'id': id,
  'name': name,
  'type': type,
  'model': model,
  'is_active': active,
};

Map<String, dynamic> _provider(String type, String label, String category) => {
  'type': type,
  'label': label,
  'category': category,
  'icon': '',
  'fields': <Object>[],
};

http.Response _json(Object body, {int statusCode = 200}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json'},
);

void main() {
  setUp(cargarTraduccionesDePrueba);

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

  List<Map<String, dynamic>> providers() => [
    _provider('openai', 'OpenAI', 'llm'),
    _provider('ssh', 'SSH', 'machine'),
    _provider('postgres', 'PostgreSQL', 'database'),
  ];

  List<Map<String, dynamic>> connections() => [
    _connection(),
    _connection(id: 'c2', name: 'Servidor', type: 'ssh', model: ''),
    _connection(id: 'c3', name: 'Datos', type: 'postgres', model: ''),
  ];

  http.Response listResponse(http.BaseRequest request) {
    if (request.url.path == '/api/connections/providers') {
      return _json(providers());
    }
    if (request.url.path == '/api/v2/connections') {
      return _json({
        'items': connections(),
        'page': {'has_more': false},
      });
    }
    return _json({});
  }

  Future<ConnectionsController> build(
    Future<http.Response> Function(http.Request request) handler, {
    String? token = 'token',
  }) async {
    final client = ApiClient(backendController, client: MockClient(handler));
    addTearDown(client.close);
    final controller = ConnectionsController(
      repository: ConnectionsRepository(apiClient: client),
      sessionController: await session(token: token),
      tx: tr,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('load trae conexiones inactivas y catálogo de proveedores', () async {
    Uri? listUri;
    final controller = await build((request) async {
      if (request.url.path == '/api/v2/connections') listUri = request.url;
      return listResponse(request);
    });

    await controller.load();

    expect(controller.loading, isFalse);
    expect(controller.error, isNull);
    expect(controller.connections, hasLength(3));
    expect(controller.providers, hasLength(3));
    expect(listUri?.queryParameters['include_inactive'], 'true');
    expect(controller.filteredConnections.single.id, 'c1');
  });

  test('load sin sesión avisa sin llamar a la API', () async {
    var calls = 0;
    final controller = await build((request) async {
      calls++;
      return listResponse(request);
    }, token: null);

    await controller.load();

    expect(calls, 0);
    expect(controller.loading, isFalse);
    expect(controller.error, 'No hay sesión activa');
  });

  test(
    'categoría, proveedor y búsqueda filtran y agrupan el listado',
    () async {
      final controller = await build((request) async => listResponse(request));
      await controller.load();

      controller.setCategoryIndex(1);
      expect(controller.currentCategory, 'machine');
      expect(controller.filteredConnections.single.id, 'c2');
      expect(controller.providerFilter, 'all');

      controller.setProviderFilter('ssh');
      expect(controller.activeFilterCount, 1);
      controller.setQuery('servidor');
      expect(controller.filteredConnections.single.name, 'Servidor');
      expect(controller.connectionsByProvider.single.key, 'SSH');

      // Cambiar de pestaña limpia el proveedor específico.
      controller.setCategoryIndex(2);
      expect(controller.providerFilter, 'all');
      expect(controller.filteredConnections, isEmpty);
    },
  );

  test('selectGroup recarga el listado con el group_id elegido', () async {
    Uri? listUri;
    final controller = await build((request) async {
      if (request.url.path == '/api/v2/connections') listUri = request.url;
      return listResponse(request);
    });

    await controller.selectGroup('g1');

    expect(controller.activeGroupId, 'g1');
    expect(listUri?.queryParameters['group_id'], 'g1');
  });

  test(
    'createConnection limita proveedores a la categoría y recarga',
    () async {
      Map<String, dynamic>? saved;
      final controller = await build((request) async {
        if (request.method == 'POST' &&
            request.url.path == '/api/connections') {
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'id': 'new'});
        }
        return listResponse(request);
      });
      await controller.load();

      final result = await controller.createConnection(
        present: (available, initial, discover) async {
          expect(available.map((provider) => provider.type), ['openai']);
          expect(initial, isNull);
          return {'name': 'Nueva', 'type': 'openai'};
        },
      );

      expect(result?.message, 'Conexión guardada');
      expect(saved?['name'], 'Nueva');
    },
  );

  test('editConnection usa el detalle y fuerza el id original', () async {
    Map<String, dynamic>? saved;
    final controller = await build((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/connections/c1') {
        return _json({..._connection(), 'host': 'detalle'});
      }
      if (request.method == 'POST' && request.url.path == '/api/connections') {
        saved = jsonDecode(request.body) as Map<String, dynamic>;
        return _json({'id': 'c1'});
      }
      return listResponse(request);
    });
    await controller.load();

    final result = await controller.editConnection(
      controller.connections.first,
      present: (available, initial, discover) async {
        expect(available, hasLength(3));
        expect(initial?['host'], 'detalle');
        return {'id': 'alterado', 'name': 'Editada'};
      },
    );

    expect(result?.isError, isFalse);
    expect(saved?['id'], 'c1');
    expect(saved?['name'], 'Editada');
  });

  test(
    'las conexiones virtuales no se editan ni eliminan ni testean',
    () async {
      var calls = 0;
      var presentations = 0;
      final controller = await build((request) async {
        calls++;
        return listResponse(request);
      });
      final virtual = ConnectionItem(
        raw: _connection(id: 'ollama::model', name: 'Virtual'),
      );

      final edited = await controller.editConnection(
        virtual,
        present: (available, initial, discover) async {
          presentations++;
          return null;
        },
      );
      final deleted = await controller.deleteConnection(
        virtual,
        confirm: () async => true,
      );
      final tested = await controller.testConnection(virtual);

      expect(edited?.message, contains('no se edita directamente'));
      expect(deleted?.message, contains('no se elimina directamente'));
      expect(tested?.message, contains('no se testea directamente'));
      expect(presentations, 0);
      expect(calls, 0);
    },
  );

  test('discoverOllamaModels devuelve vacío cuando el host falla', () async {
    final controller = await build((request) async {
      if (request.url.path == '/api/connections/ollama-models') {
        return _json({'detail': 'offline'}, statusCode: 503);
      }
      return listResponse(request);
    });

    expect(await controller.discoverOllamaModels('http://ollama'), isEmpty);
  });

  test('toggleActive llama a activate y devuelve el mensaje', () async {
    String? mutationPath;
    final controller = await build((request) async {
      if (request.method == 'POST' &&
          (request.url.path.endsWith('/activate') ||
              request.url.path.endsWith('/deactivate'))) {
        mutationPath = request.url.path;
        return _json({});
      }
      return listResponse(request);
    });
    await controller.load();

    final result = await controller.toggleActive(
      ConnectionItem(raw: _connection(active: false)),
    );

    expect(mutationPath, '/api/connections/c1/activate');
    expect(result?.message, 'Conexión activada');
  });

  test('syncHub resume los recursos importados', () async {
    final controller = await build((request) async {
      if (request.url.path.endsWith('/hub-sync')) {
        return _json({
          'agents': 1,
          'skills': 2,
          'knowledge': 3,
          'connections': 4,
        });
      }
      return listResponse(request);
    });
    await controller.load();

    final result = await controller.syncHub(controller.connections.first);

    expect(
      result?.message,
      'Sincronizado: 1 agentes · 2 skills · 3 conocimiento · 4 conexiones',
    );
  });

  test('deleteConnection respeta la confirmación', () async {
    var deletes = 0;
    final controller = await build((request) async {
      if (request.method == 'DELETE') {
        deletes++;
        return _json({});
      }
      return listResponse(request);
    });
    await controller.load();
    final item = controller.connections.first;

    expect(
      await controller.deleteConnection(item, confirm: () async => false),
      isNull,
    );
    final result = await controller.deleteConnection(
      item,
      confirm: () async => true,
    );

    expect(deletes, 1);
    expect(result?.message, 'Conexión eliminada');
  });

  test('testConnection conserva estado, mensaje y detalle', () async {
    final controller = await build((request) async {
      if (request.url.path.endsWith('/test')) {
        return _json({
          'id': 'c1',
          'ok': false,
          'message': 'Falló',
          'detail': 'Timeout',
        });
      }
      return listResponse(request);
    });
    await controller.load();

    await controller.testConnection(controller.connections.first);

    expect(controller.testStatus('c1'), ConnectionTestStatus.error);
    expect(controller.testMessage('c1'), 'Falló\nTimeout');
  });

  test(
    'testConnection traduce credential_unreadable aunque responda 200',
    () async {
      final controller = await build((request) async {
        if (request.url.path.endsWith('/test')) {
          return _json({
            'id': 'c1',
            'ok': false,
            'code': 'credential_unreadable',
            'message': 'Fallback sin traducir',
            'detail': '',
          });
        }
        return listResponse(request);
      });
      await controller.load();

      await controller.testConnection(controller.connections.first);

      expect(
        controller.testMessage('c1'),
        'La credencial guardada no se puede leer. Edítala e introdúcela de nuevo.',
      );
    },
  );

  test('testAll usa sólo el filtro visible y presenta el resumen', () async {
    Map<String, dynamic>? body;
    ConnectionsMassTestSummary? shown;
    final controller = await build((request) async {
      if (request.url.path == '/api/connections/test-all') {
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return _json([
          {'id': 'c2', 'ok': true, 'message': 'OK', 'latency_ms': 12},
        ]);
      }
      return listResponse(request);
    });
    await controller.load();
    controller.setCategoryIndex(1);

    final result = await controller.testAll(
      present: (summary) async {
        shown = summary;
        expect(controller.testingAll, isTrue);
      },
    );

    expect(result, isNull);
    expect(body?['ids'], ['c2']);
    expect(shown?.passed, 1);
    expect(shown?.failed, 0);
    expect(shown?.namesById['c2'], 'Servidor');
    expect(controller.testStatus('c2'), ConnectionTestStatus.ok);
    expect(controller.testingAll, isFalse);
  });

  test('testAll limpia pending cuando falla el endpoint', () async {
    final controller = await build((request) async {
      if (request.url.path == '/api/connections/test-all') {
        return _json({'detail': 'Servicio caído'}, statusCode: 503);
      }
      return listResponse(request);
    });
    await controller.load();

    final result = await controller.testAll(present: (_) async {});

    expect(result?.isError, isTrue);
    expect(result?.message, contains('Servicio caído'));
    expect(controller.testStatus('c1'), isNull);
    expect(controller.testingAll, isFalse);
  });
}
