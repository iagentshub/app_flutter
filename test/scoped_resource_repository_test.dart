import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/core/network/cursor_page_collector.dart';
import 'package:app_flutter/features/agents/repositories/agents_repository.dart';
import 'package:app_flutter/features/knowledge/repositories/prompts_repository.dart';
import 'package:app_flutter/features/knowledge/repositories/skills_repository.dart';
import 'package:app_flutter/features/knowledge/repositories/tools_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/i18n_de_prueba.dart';

/// Los repositorios de skills, prompts y tools eran el mismo fichero repetido:
/// cada cambio del contrato había que aplicarlo tres veces y era fácil olvidar
/// una. De hecho ya había divergencia en cómo se codificaba el `group_id`.
/// Ahora el contrato vive en un solo sitio y estas pruebas lo fijan.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late BackendController backendController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    backendController = await BackendController.bootstrap();
  });

  /// Devuelve el cliente y la lista de URLs que ha pedido.
  (ApiClient, List<Uri>) clienteEspia({
    String body = '{"items":[],"page":{"has_more":false}}',
  }) {
    final peticiones = <Uri>[];
    final mock = MockClient((request) async {
      peticiones.add(request.url);
      return http.Response(
        body,
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);
    return (client, peticiones);
  }

  test('el listado codifica scope y grupo igual en los tres', () async {
    final (client, peticiones) = clienteEspia();

    await SkillsRepository(apiClient: client)
        .listSkills('token', scope: 'group', groupId: 'ORANGE JAZZTEL/2026');
    await PromptsRepository(apiClient: client)
        .listPrompts('token', scope: 'group', groupId: 'ORANGE JAZZTEL/2026');
    await ToolsRepository(apiClient: client)
        .listTools('token', scope: 'group', groupId: 'ORANGE JAZZTEL/2026');

    expect(peticiones, hasLength(3));
    expect(peticiones.map((uri) => uri.path).toList(), [
      '/api/v2/skills',
      '/api/v2/prompts',
      '/api/v2/tools',
    ]);
    // El mismo contrato para los tres, sin depender de cómo cada repositorio
    // arme la query a mano.
    for (final uri in peticiones) {
      expect(uri.queryParameters['scope'], 'group');
      expect(uri.queryParameters['group_id'], 'ORANGE JAZZTEL/2026');
      expect(uri.queryParameters.containsKey('include_total'), isFalse);
    }
  });

  test('los cuatro catálogos omiten el total exacto por defecto', () async {
    final (client, peticiones) = clienteEspia();

    await AgentsRepository(apiClient: client).listAgents('token');
    await SkillsRepository(apiClient: client).listSkills('token');
    await PromptsRepository(apiClient: client).listPrompts('token');
    await ToolsRepository(apiClient: client).listTools('token');

    expect(peticiones, hasLength(4));
    for (final uri in peticiones) {
      expect(uri.queryParameters.containsKey('include_total'), isFalse);
    }
  });

  test('sin grupo no se manda ese parámetro', () async {
    final (client, peticiones) = clienteEspia();

    await SkillsRepository(apiClient: client).listSkills('token');

    expect(peticiones.single.queryParameters, {'scope': 'all', 'limit': '100'});
  });

  test('el listado completo avanza con el cursor opaco del backend', () async {
    final peticiones = <Uri>[];
    var llamada = 0;
    final mock = MockClient((request) async {
      peticiones.add(request.url);
      llamada++;
      return http.Response(
        jsonEncode({
          'items': [
            {'id': 'skill-$llamada', 'name': 'Skill $llamada'},
          ],
          'page': {
            'has_more': llamada == 1,
            if (llamada == 1) 'next_cursor': 'cursor-opaco-2',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    final skills = await SkillsRepository(apiClient: client)
        .listSkills('token');

    expect(skills, hasLength(2));
    expect(peticiones, hasLength(2));
    expect(peticiones.first.queryParameters.containsKey('cursor'), isFalse);
    expect(peticiones.last.queryParameters['cursor'], 'cursor-opaco-2');
    expect(
      peticiones.every((uri) => !uri.queryParameters.containsKey('offset')),
      isTrue,
    );
  });

  test(
    'agents tambien recorre paginas por cursor y nunca por offset',
    () async {
      final peticiones = <Uri>[];
      var llamada = 0;
      final mock = MockClient((request) async {
        peticiones.add(request.url);
        llamada++;
        return http.Response(
          jsonEncode({
            'items': [
              {'id': 'agent-$llamada', 'name': 'Agent $llamada'},
            ],
            'page': {
              'has_more': llamada == 1,
              if (llamada == 1) 'next_cursor': 'agents-cursor-2',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = ApiClient(backendController, client: mock);
      addTearDown(client.close);

      final agents = await AgentsRepository(apiClient: client)
          .listAgents('token');

      expect(agents, hasLength(2));
      expect(peticiones.last.queryParameters['cursor'], 'agents-cursor-2');
      expect(
        peticiones.every((uri) => !uri.queryParameters.containsKey('offset')),
        isTrue,
      );
    },
  );

  test('hasMore sin nextCursor se rechaza con codigo estable', () async {
    final mock = MockClient(
      (_) async => http.Response(
        '{"items":[{"id":"skill-1","name":"Skill"}],"page":{"has_more":true}}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    await expectLater(
      SkillsRepository(apiClient: client).listSkills('token'),
      throwsA(
        isA<CursorPaginationException>().having(
          (error) => error.code,
          'code',
          'pagination_missing_next_cursor',
        ),
      ),
    );
  });

  test('un cursor repetido se rechaza sin entrar en bucle', () async {
    final mock = MockClient(
      (_) async => http.Response(
        '{"items":[],"page":{"has_more":true,"next_cursor":"igual"}}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);

    await expectLater(
      SkillsRepository(apiClient: client).listSkills('token'),
      throwsA(
        isA<CursorPaginationException>().having(
          (error) => error.code,
          'code',
          'pagination_repeated_cursor',
        ),
      ),
    );
  });

  test('los errores cursor se resuelven en el idioma activo', () {
    cargarTraduccionesDePrueba();
    expect(
      const CursorPaginationException.repeatedCursor().message,
      'El backend repitió el cursor de paginación.',
    );
    expect(
      const CursorPaginationException.missingNextCursor().message,
      'El backend indicó que hay más resultados, pero no proporcionó el cursor siguiente.',
    );

    cargarTraduccionesDePrueba(idioma: 'en');
    expect(
      const CursorPaginationException.repeatedCursor().message,
      'The backend repeated the pagination cursor.',
    );
    expect(
      const CursorPaginationException.missingNextCursor().message,
      'The backend reported more results but did not provide the next cursor.',
    );
  });

  test('el id y el scope se codifican en la ruta', () async {
    final (client, peticiones) = clienteEspia(body: '{}');

    await SkillsRepository(apiClient: client)
        .getSkill('token', 'group', 'id con espacios/y barra');

    // La barra del id queda escapada, así que no abre un segmento de ruta
    // nuevo ni permite salirse del recurso.
    expect(
      peticiones.single.path,
      '/api/skills/group/id%20con%20espacios%2Fy%20barra',
    );
    expect(peticiones.single.pathSegments, [
      'api',
      'skills',
      'group',
      'id con espacios/y barra',
    ]);
  });

  test('el listado v2 rechaza un envelope inválido', () async {
    final (client, _) = clienteEspia(body: '{"error":"vaya"}');

    await expectLater(
      SkillsRepository(apiClient: client).listSkills('t'),
      throwsA(
        isA<CursorPaginationException>().having(
          (error) => error.code,
          'code',
          'pagination_invalid_response',
        ),
      ),
    );
  });

  test('skills y prompts envían las labels de idioma sin alterar', () async {
    final requests = <http.Request>[];
    final mock = MockClient((request) async {
      requests.add(request);
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = ApiClient(backendController, client: mock);
    addTearDown(client.close);
    final payload = {
      'name': 'Contenido bilingüe',
      'labels': ['private', 'lang_es', 'lang_en'],
    };

    await SkillsRepository(apiClient: client)
        .saveSkill('token', 'private', payload);
    await PromptsRepository(apiClient: client)
        .savePrompt('token', 'private', payload);

    expect(requests.map((request) => request.url.path), [
      '/api/skills/private',
      '/api/prompts/private',
    ]);
    for (final request in requests) {
      expect(jsonDecode(request.body)['labels'], [
        'private',
        'lang_es',
        'lang_en',
      ]);
    }
  });

  test('activación usa scope e id en skills, prompts y tools', () async {
    final (client, peticiones) = clienteEspia(body: '{}');

    await SkillsRepository(apiClient: client)
        .setSkillActive('token', 'private', 'skill 1', false);
    await PromptsRepository(apiClient: client)
        .setPromptActive('token', 'public', 'prompt 1', true);
    await ToolsRepository(apiClient: client)
        .setToolActive('token', 'private', 'tool 1', false);

    expect(peticiones.map((uri) => uri.path).toList(), [
      '/api/skills/private/skill%201/deactivate',
      '/api/prompts/public/prompt%201/activate',
      '/api/tools/private/tool%201/deactivate',
    ]);
  });
}
