import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/agents/controllers/agent_builder_controller.dart';
import 'package:app_flutter/features/agents/repositories/agent_builder_repository.dart';
import 'package:app_flutter/features/agents/repositories/agents_repository.dart';
import 'package:app_flutter/features/connections/repositories/connections_repository.dart';
import 'package:app_flutter/features/knowledge/repositories/knowledge_repository.dart';
import 'package:app_flutter/features/knowledge/repositories/skills_repository.dart';
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
  String id = 'connection-1',
  String name = 'OpenAI',
}) => {'id': id, 'name': name, 'type': 'openai', 'model': 'gpt-5'};

http.Response _json(Object body, {int statusCode = 200}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json'},
);

http.Response _sse(List<Map<String, dynamic>> events) => http.Response.bytes(
  utf8.encode(events.map((event) => 'data: ${jsonEncode(event)}').join('\n\n')),
  200,
  headers: {'content-type': 'text/event-stream; charset=utf-8'},
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

  http.Response resourcesResponse(
    http.BaseRequest request, {
    List<Map<String, dynamic>>? connections,
  }) {
    switch (request.url.path) {
      case '/api/v2/connections':
        return _json({
          'items': connections ?? [_connection()],
          'page': {'has_more': false},
        });
      case '/api/v2/skills':
        return _json({
          'items': [
            {'id': 'skill-1', 'name': 'Soporte'},
          ],
          'page': {'has_more': false},
        });
      case '/api/v2/knowledge':
        return _json({
          'items': [
            {'id': 'knowledge-1', 'title': 'Manual'},
          ],
          'page': {'has_more': false},
        });
      default:
        return _json({});
    }
  }

  Future<AgentBuilderController> build(
    Future<http.Response> Function(http.Request request) handler, {
    String? token = 'token',
  }) async {
    final client = ApiClient(backendController, client: MockClient(handler));
    addTearDown(client.close);
    final controller = AgentBuilderController(
      builderRepository: AgentBuilderRepository(apiClient: client),
      agentsRepository: AgentsRepository(apiClient: client),
      connectionsRepository: ConnectionsRepository(apiClient: client),
      skillsRepository: SkillsRepository(apiClient: client),
      knowledgeRepository: KnowledgeRepository(apiClient: client),
      sessionController: await session(token: token),
      tx: tr,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('load prepara conexiones, skills y conocimiento para el chat', () async {
    final controller = await build(
      (request) async => resourcesResponse(request),
    );

    await controller.load();

    expect(controller.loadingConnections, isFalse);
    expect(controller.error, isNull);
    expect(controller.connections.single.id, 'connection-1');
    expect(controller.connectionId, 'connection-1');
    expect(controller.canSend, isTrue);
  });

  test('load sin sesión avisa y no llama a la API', () async {
    var calls = 0;
    final controller = await build((request) async {
      calls++;
      return resourcesResponse(request);
    }, token: null);

    await controller.load();

    expect(calls, 0);
    expect(controller.loadingConnections, isFalse);
    expect(controller.error, 'No hay sesión activa');
  });

  test('el fallo de un catálogo no impide usar los demás', () async {
    final controller = await build((request) async {
      if (request.url.path == '/api/v2/skills') {
        return _json({'detail': 'Skills caído'}, statusCode: 503);
      }
      return resourcesResponse(request);
    });

    await controller.load();

    expect(controller.connections, hasLength(1));
    expect(controller.connectionId, 'connection-1');
    expect(controller.error, 'No se pudieron cargar: skills');
  });

  test('send exige conexión sin borrar el texto escrito', () async {
    final controller = await build(
      (request) async => resourcesResponse(request, connections: const []),
    );
    await controller.load();
    controller.textController.text = 'Crea un agente';

    final result = await controller.send();

    expect(result?.isError, isTrue);
    expect(result?.message, 'Elige una conexión primero');
    expect(controller.textController.text, 'Crea un agente');
    expect(controller.messages, isEmpty);
  });

  test('send transmite catálogos y conserva respuesta y borrador', () async {
    Map<String, dynamic>? requestBody;
    final labels = <String>[];
    final controller = await build((request) async {
      if (request.url.path == '/api/agent-builder/chat') {
        requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        return _sse([
          {
            'type': 'progress',
            'stage': 'drafting',
            'assistant_message': 'Preparando…',
          },
          {
            'type': 'builder_done',
            'status': 'ready',
            'assistant_message': 'Borrador listo',
            'draft': {'name': 'Agente de soporte', 'use_memory': true},
          },
        ]);
      }
      return resourcesResponse(request);
    });
    controller.addListener(() {
      if (controller.thinking) labels.add(controller.thinkingLabel);
    });
    await controller.load();
    controller.textController.text = '  Ayuda a clientes  ';

    final result = await controller.send();

    expect(result, isNull);
    expect(controller.error, isNull);
    expect(controller.streaming, isFalse);
    expect(controller.thinking, isFalse);
    expect(controller.textController.text, isEmpty);
    expect(controller.messages.map((message) => message.content), [
      'Ayuda a clientes',
      'Borrador listo',
    ]);
    expect(controller.pendingDraft?['name'], 'Agente de soporte');
    expect(labels, contains('Preparando el borrador…'));
    expect(requestBody?['connection_id'], 'connection-1');
    expect(requestBody?['messages'], [
      {'role': 'user', 'content': 'Ayuda a clientes'},
    ]);
    expect(requestBody?['resources'], {
      'skills': [
        {'id': 'skill-1', 'name': 'Soporte'},
      ],
      'knowledge': [
        {'id': 'knowledge-1', 'name': 'Manual'},
      ],
    });
  });

  test('un error SSE queda visible hasta el siguiente envío', () async {
    final controller = await build((request) async {
      if (request.url.path == '/api/agent-builder/chat') {
        return _sse([
          {'type': 'error', 'message': 'El proveedor no responde'},
        ]);
      }
      return resourcesResponse(request);
    });
    await controller.load();
    controller.textController.text = 'Hola';

    await controller.send();

    expect(controller.error, 'El proveedor no responde');
    expect(controller.streaming, isFalse);
    expect(controller.messages.single.content, 'Hola');
  });

  test('el 404 restaura el prompt y descarta la conexión obsoleta', () async {
    var connectionRequests = 0;
    final controller = await build((request) async {
      if (request.url.path == '/api/v2/connections') {
        connectionRequests++;
        return _json({
          'items': [
            connectionRequests == 1
                ? _connection(id: 'stale', name: 'Antigua')
                : _connection(id: 'available', name: 'Disponible'),
          ],
          'page': {'has_more': false},
        });
      }
      if (request.url.path == '/api/agent-builder/chat') {
        return _json({
          'detail': {
            'code': 'not_found',
            'message': 'La conexión ya no existe',
          },
        }, statusCode: 404);
      }
      return resourcesResponse(request);
    });
    await controller.load();
    controller.textController.text = 'Crea un agente de soporte';

    await controller.send();

    expect(connectionRequests, 2);
    expect(controller.error, 'La conexión ya no existe');
    expect(controller.textController.text, 'Crea un agente de soporte');
    expect(controller.messages, isEmpty);
    expect(controller.connections.single.id, 'available');
    expect(controller.connectionId, 'available');
  });

  test(
    'reviewDraft prepara el formulario y guarda el payload aceptado',
    () async {
      Map<String, dynamic>? savedPayload;
      final controller = await build((request) async {
        if (request.url.path == '/api/agent-builder/chat') {
          return _sse([
            {
              'type': 'builder_done',
              'status': 'ready',
              'draft': {'name': 'Agente Ventas Norte', 'use_memory': true},
            },
          ]);
        }
        if (request.method == 'POST' && request.url.path == '/api/agents') {
          savedPayload = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'id': 'agent-1'});
        }
        return resourcesResponse(request);
      });
      await controller.load();
      controller.textController.text = 'Crea el agente';
      await controller.send();
      Map<String, dynamic>? presentedInitial;

      final result = await controller.reviewDraft(
        present: (initial, token) async {
          presentedInitial = initial;
          expect(token, 'token');
          return {...initial, 'description': 'Validado'};
        },
      );

      expect(presentedInitial?['connection_id'], 'connection-1');
      expect(presentedInitial?['memory_file'], 'agente-ventas-norte.md');
      expect(savedPayload?['description'], 'Validado');
      expect(result?.message, 'Agente creado');
      expect(controller.agentSaved, isTrue);
      expect(controller.pendingDraft, isNull);
    },
  );

  test('reviewDraft cancelado no llama al backend', () async {
    var saves = 0;
    final controller = await build((request) async {
      if (request.url.path == '/api/agent-builder/chat') {
        return _sse([
          {
            'type': 'builder_done',
            'status': 'ready',
            'draft': {'name': 'Agente'},
          },
        ]);
      }
      if (request.url.path == '/api/agents') saves++;
      return resourcesResponse(request);
    });
    await controller.load();
    controller.textController.text = 'Crea el agente';
    await controller.send();

    final result = await controller.reviewDraft(
      present: (initial, token) async => null,
    );

    expect(result, isNull);
    expect(saves, 0);
    expect(controller.pendingDraft, isNotNull);
  });

  test('stop cierra el envío pendiente sin esperar al servidor', () async {
    final responseGate = Completer<http.Response>();
    final controller = await build((request) async {
      if (request.url.path == '/api/agent-builder/chat') {
        return responseGate.future;
      }
      return resourcesResponse(request);
    });
    await controller.load();
    controller.textController.text = 'Crea el agente';

    final pending = controller.send();
    expect(controller.streaming, isTrue);
    controller.stop();
    await pending;

    expect(controller.streaming, isFalse);
    expect(controller.thinking, isFalse);
    responseGate.complete(_sse(const []));
  });
}
