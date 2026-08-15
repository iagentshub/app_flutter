import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/knowledge/repositories/prompts_repository.dart';
import 'package:app_flutter/features/knowledge/repositories/skills_repository.dart';
import 'package:app_flutter/features/knowledge/repositories/tools_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  (ApiClient, List<Uri>) clienteEspia({String body = '[]'}) {
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

  test(
    'el listado codifica scope, grupo e inactivos igual en los tres',
    () async {
      final (client, peticiones) = clienteEspia();

      await SkillsRepository(apiClient: client).listSkills(
        'token',
        scope: 'group',
        groupId: 'ORANGE JAZZTEL/2026',
        includeInactive: true,
      );
      await PromptsRepository(apiClient: client).listPrompts(
        'token',
        scope: 'group',
        groupId: 'ORANGE JAZZTEL/2026',
        includeInactive: true,
      );
      await ToolsRepository(apiClient: client).listTools(
        'token',
        scope: 'group',
        groupId: 'ORANGE JAZZTEL/2026',
        includeInactive: true,
      );

      expect(peticiones, hasLength(3));
      expect(peticiones.map((uri) => uri.path).toList(), [
        '/api/skills',
        '/api/prompts',
        '/api/tools',
      ]);
      // El mismo contrato para los tres, sin depender de cómo cada repositorio
      // arme la query a mano.
      for (final uri in peticiones) {
        expect(uri.queryParameters['scope'], 'group');
        expect(uri.queryParameters['group_id'], 'ORANGE JAZZTEL/2026');
        expect(uri.queryParameters['include_inactive'], 'true');
      }
    },
  );

  test('sin grupo ni inactivos no se mandan esos parámetros', () async {
    final (client, peticiones) = clienteEspia();

    await SkillsRepository(apiClient: client).listSkills('token');

    expect(peticiones.single.queryParameters, {
      'scope': 'all',
      'limit': '100',
      'offset': '0',
    });
  });

  test('el id y el scope se codifican en la ruta', () async {
    final (client, peticiones) = clienteEspia(body: '{}');

    await SkillsRepository(
      apiClient: client,
    ).getSkill('token', 'group', 'id con espacios/y barra');

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

  test('el listado ignora una respuesta que no sea una lista', () async {
    final (client, _) = clienteEspia(body: '{"error":"vaya"}');

    final skills = await SkillsRepository(apiClient: client).listSkills('t');

    expect(skills, isEmpty);
  });

  test('activar y desactivar usan el endpoint común de cada recurso', () async {
    final (client, peticiones) = clienteEspia(body: '{}');

    await SkillsRepository(apiClient: client).setSkillActive('t', 'a1', true);
    await PromptsRepository(
      apiClient: client,
    ).setPromptActive('t', 'p1', false);
    await ToolsRepository(apiClient: client).setToolActive('t', 'h1', true);

    expect(peticiones.map((uri) => uri.path).toList(), [
      '/api/skills/a1/activate',
      '/api/prompts/p1/deactivate',
      '/api/tools/h1/activate',
    ]);
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

    await SkillsRepository(
      apiClient: client,
    ).saveSkill('token', 'private', payload);
    await PromptsRepository(
      apiClient: client,
    ).savePrompt('token', 'private', payload);

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
}
