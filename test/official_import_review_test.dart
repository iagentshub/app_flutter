import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/models/official_import_models.dart';
import 'package:app_flutter/features/admin/pages/official_import_review_page.dart';
import 'package:app_flutter/features/admin/repositories/admin_connections_repository.dart';
import 'package:app_flutter/features/admin/repositories/admin_official_sources_repository.dart';
import 'package:app_flutter/features/admin/widgets/official_import_component_tile.dart';
import 'package:app_flutter/features/admin/widgets/official_import_progress_dialog.dart';
import 'package:app_flutter/shared/graph/animated_resource_graph.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/i18n_de_prueba.dart';

void main() {
  setUp(cargarTraduccionesDePrueba);

  TestWidgetsFlutterBinding.ensureInitialized();

  test('parsea borrador, componentes, diff y procedencia tipados', () {
    final draft = ImportDraft.fromJson(_draftJson());
    final diff = ImportDiff.fromJson({
      'counts': {'create': 1, 'update': 2, 'delete': 3, 'unchanged': 4},
      'warnings': ['license'],
    });
    final origin = OriginInfo.fromJson({
      'source_id': 'source-1',
      'source_name': 'Demo',
      'repository_url': 'https://github.com/example/demo',
      'source_path': 'skills/demo/SKILL.md',
      'commit_sha': 'abc',
    });

    expect(draft.id, 'draft-1');
    expect(draft.components.single.selected, isFalse);
    expect(draft.components.single.state, 'new');
    expect(draft.logs, isEmpty);
    expect(diff.counts['delete'], 3);
    expect(origin.sourcePath, 'skills/demo/SKILL.md');
  });

  test('compatibilidad LLM viene resuelta por el catálogo del backend', () {
    final chat = OfficialImportLlmConnection.fromJson({
      'id': 'future-provider-1',
      'name': 'Proveedor futuro',
      'type': 'future-provider',
      'model': 'model-1',
      'supports_chat': true,
    });
    final nonChat = OfficialImportLlmConnection.fromJson({
      'id': 'ssh-1',
      'name': 'Servidor',
      'type': 'ssh',
      'supports_chat': false,
    });

    expect(chat.compatible, isTrue);
    expect(nonChat.compatible, isFalse);
  });

  test('selector LLM conserva solo conexiones activas con chat', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final repository = AdminConnectionsRepository(
      apiClient: ApiClient(
        backend,
        client: MockClient(
          (_) async => _json([
            {
              'id': 'future-1',
              'name': 'Future',
              'type': 'future-provider',
              'model': 'future-model',
              'supports_chat': true,
              'is_active': true,
            },
            {
              'id': 'ssh-1',
              'name': 'SSH',
              'type': 'ssh',
              'supports_chat': false,
              'is_active': true,
            },
            {
              'id': 'disabled-1',
              'name': 'Disabled',
              'type': 'openai',
              'supports_chat': true,
              'is_active': false,
            },
          ]),
        ),
      ),
    );

    final connections = await repository.listLlmConnections('token');

    expect(connections.map((item) => item.id), ['future-1']);
    expect(connections.single.displayName, 'Future · future-model');
  });

  test('separa los eventos de log de las advertencias', () {
    final draft = ImportDraft.fromJson({
      ..._draftJson(),
      'security_warnings': [
        'Revisar licencia',
        'reviewer: referencia fuera del repositorio (../../guide.md)',
        {
          'level': 'log',
          'code': 'external_markdown_reference',
          'message': 'Referencia externa detectada',
        },
      ],
    });

    expect(draft.warnings, ['Revisar licencia']);
    expect(draft.logs, [
      'reviewer: referencia fuera del repositorio (../../guide.md)',
      'Referencia externa detectada',
    ]);
  });

  test('normaliza commands como prompts y conserva relaciones tipadas', () {
    final component = ImportComponent.fromJson({
      'component_id': 'plan',
      'component_type': 'command',
      'name': 'Plan',
      'source_path': 'commands/plan.md',
      'relations': [
        {'target_id': 'reviewer', 'relation_type': 'orchestrates'},
      ],
    });

    expect(component.effectiveType, 'prompt');
    expect(component.relations.single.type, 'orchestrates');
  });

  test('separa idioma humano y lenguaje de ejecución de una tool', () {
    final invalid = ImportComponent.fromJson({
      'component_id': 'runner',
      'component_type': 'tool',
      'name': 'Runner',
      'source_path': 'tools/runner.js',
      'language': 'lang_javascript',
      'tool_language': 'javascript',
    });
    final valid = ImportComponent.fromJson({
      'component_id': 'runner',
      'component_type': 'tool',
      'name': 'Runner',
      'source_path': 'tools/runner.py',
      'language': 'lang_en',
      'forced_tool_language': 'python',
    });

    expect(invalid.language, isEmpty);
    expect(invalid.toolLanguage, isNull);
    expect(valid.language, 'lang_en');
    expect(valid.toolLanguage?.apiValue, 'python');

    expect(
      ImportComponent.fromJson({
        'component_id': 'shell',
        'component_type': 'tool',
        'source_path': 'tools/run.SH',
      }).toolLanguage?.apiValue,
      'shell',
    );
    expect(
      ImportComponent.fromJson({
        'component_id': 'native',
        'component_type': 'tool',
        'source_path': 'tools/run.cpp',
      }).toolLanguage?.apiValue,
      'cpp',
    );
  });

  test('serializa el lenguaje tipado con el contrato de API', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    Map<String, dynamic>? body;
    final repository = AdminOfficialSourcesRepository(
      apiClient: ApiClient(
        backend,
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({
            'component_id': 'runner',
            'component_type': 'tool',
            'source_path': 'tools/runner.sh',
            'forced_tool_language': body?['forced_tool_language'],
          });
        }),
      ),
    );

    final updated = await repository.updateDraftComponent(
      'token',
      'draft-1',
      'runner',
      forcedToolLanguage: 'shell',
    );

    expect(body?['forced_tool_language'], 'shell');
    expect(updated.toolLanguage?.apiValue, 'shell');
  });

  testWidgets('traduce la opción sin especificar de ambos idiomas', (
    tester,
  ) async {
    final component = ImportComponent.fromJson({
      'component_id': 'runner',
      'component_type': 'tool',
      'name': 'Runner',
      'source_path': 'tools/runner',
    });

    Widget tile() => MaterialApp(
      home: Scaffold(
        body: OfficialImportComponentTile(
          component: component,
          busy: false,
          tx: tr,
          onToggle: (_) {},
          onClassify: (_) {},
          onLanguage: (_) {},
          onToolLanguage: (_) {},
          onEditRelations: () {},
          onReviewTool: () {},
        ),
      ),
    );

    await tester.pumpWidget(tile());
    expect(find.text('Sin especificar'), findsNWidgets(2));

    cargarTraduccionesDePrueba(idioma: 'en');
    await tester.pumpWidget(tile());
    expect(find.text('Not specified'), findsNWidgets(2));
    expect(find.text('Sin especificar'), findsNothing);
  });

  test('envía el modo LLM y la conexión seleccionada', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    Map<String, dynamic>? body;
    final repository = AdminOfficialSourcesRepository(
      apiClient: ApiClient(
        backend,
        client: MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return _json(_draftJson());
        }),
      ),
    );

    await repository.importRepository(
      'token',
      'https://github.com/example/demo',
      importMode: 'llm',
      llmConnectionId: 'connection-1',
    );

    expect(body?['import_mode'], 'llm');
    expect(body?['llm_connection_id'], 'connection-1');
  });

  test('recibe progreso y resultado por streaming sin timeout corto', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final repository = AdminOfficialSourcesRepository(
      apiClient: ApiClient(
        backend,
        client: MockClient(
          (_) async => http.Response(
            'data: {"type":"started"}\n\n'
            'data: {"type":"progress","stage":"llm_analyzing",'
            '"current":1,"total":3,"files":20,"components":4,'
            '"paths":["agents/reviewer.md"]}\n\n'
            'data: {"type":"result","draft":${jsonEncode(_draftJson())}}\n\n',
            200,
            headers: {'content-type': 'text/event-stream'},
          ),
        ),
      ),
    );

    final events = await repository
        .importRepositoryStream(
          'token',
          'https://github.com/example/demo',
          importMode: 'llm',
          llmConnectionId: 'connection-1',
        )
        .toList();

    expect(events.first.progress?.stage, 'llm_analyzing');
    expect(events.first.progress?.components, 4);
    expect(events.first.progress?.paths, ['agents/reviewer.md']);
    expect(events.last.draft?.id, 'draft-1');
  });

  test('carga todos los componentes de un borrador paginado', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    var pages = 0;
    final client = MockClient((request) async {
      if (request.method == 'POST' && request.url.path.endsWith('/inspect')) {
        return _json({
          ..._draftJson(),
          'components': [],
          'component_count': 501,
        });
      }
      if (request.method == 'GET' && request.url.path.endsWith('/components')) {
        pages += 1;
        final cursor = request.url.queryParameters['cursor'];
        final offset = cursor == null ? 0 : 500;
        final length = cursor == null ? 500 : 1;
        return _json({
          'items': List.generate(length, (index) {
            final id = offset + index;
            return {
              'component_id': 'skill-$id',
              'component_type': 'skill',
              'name': 'Skill $id',
              'source_path': 'skills/$id/SKILL.md',
              'state': 'new',
              'selected': false,
              'materializable': true,
              'dependencies': <Object>[],
              'variants': <Object>[],
            };
          }),
          'page': {
            'limit': 500,
            'has_more': cursor == null,
            'next_cursor': cursor == null ? 'page-2' : null,
            'total': 501,
          },
        });
      }
      return _json({}, statusCode: 404);
    });
    final repository = AdminOfficialSourcesRepository(
      apiClient: ApiClient(backend, client: client),
    );

    final draft = await repository.importRepository(
      'token',
      'https://github.com/example/demo',
    );

    expect(draft.components, hasLength(501));
    expect(pages, 2);
  });

  testWidgets(
    'la revisión es responsive y conserva la selección inicial vacía',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = await BackendController.bootstrap();
      final repository = AdminOfficialSourcesRepository(
        apiClient: ApiClient(
          backend,
          client: MockClient((_) async => _json({})),
        ),
      );
      for (final width in [360.0, 768.0, 1024.0, 1440.0, 1920.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: OfficialImportReviewPage(
              draft: ImportDraft.fromJson(_draftJson()),
              repository: repository,
              token: 'token',
              tx: tr,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Demo skill'), findsNothing);
        await tester.tap(find.text('skills (1)'));
        await tester.pumpAndSettle();
        if (width < 600) {
          expect(
            tester.widget<Checkbox>(find.byType(Checkbox).first).value,
            isFalse,
          );
          expect(find.text('Aplicar cambios'), findsOneWidget);
        } else {
          final tile = tester.widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Demo skill'),
          );
          expect(tile.value, isFalse);
        }
        expect(tester.takeException(), isNull, reason: 'width=$width');
        await tester.tap(find.text('skills (1)'));
        await tester.pumpAndSettle();
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

  testWidgets('muestra progreso y hallazgos del análisis LLM', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final events = StreamController<OfficialImportEvent>(sync: true);
    addTearDown(events.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OfficialImportProgressDialog(events: events.stream, tx: tr),
      ),
    );
    events.add(
      const OfficialImportEvent(
        progress: OfficialImportProgress(
          stage: 'llm_analyzing',
          current: 2,
          total: 5,
          files: 42,
          components: 9,
          paths: ['agents/reviewer.md', 'skills/review/SKILL.md'],
        ),
      ),
    );
    await tester.pump();

    expect(find.text('El LLM está analizando el repositorio'), findsOneWidget);
    expect(find.text('Fragmento 2 de 5'), findsOneWidget);
    expect(find.text('42 archivos · 9 candidatos encontrados'), findsOneWidget);
    expect(find.text('Actividad (1)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);

    events.add(
      const OfficialImportEvent(
        progress: OfficialImportProgress(
          stage: 'llm_chunk_complete',
          current: 2,
          total: 5,
          files: 42,
          components: 10,
          chunkComponents: 1,
          chunkRelations: 2,
          findings: [
            OfficialImportFinding(
              name: 'Reviewer',
              resourceType: 'agent',
              sourcePath: 'agents/reviewer.md',
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    final activityButton = find.text('Actividad (3)', skipOffstage: false);
    expect(activityButton, findsOneWidget);
    await tester.ensureVisible(activityButton);
    await tester.tap(activityButton);
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining(
        'Detectado agent: Reviewer · agents/reviewer.md',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    events.add(
      const OfficialImportEvent(
        error: 'El modelo no devolvió el manifiesto requerido',
      ),
    );
    await tester.pump();
    expect(
      find.text('El modelo no devolvió el manifiesto requerido'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(0.4, 0.001),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:02'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seleccionar actualiza el borrador del servidor', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    var selected = false;
    final client = MockClient((request) async {
      if (request.method == 'PATCH') {
        selected =
            (jsonDecode(request.body) as Map<String, dynamic>)['selected'] ==
            true;
        final component =
            (_draftJson(selected: selected)['components'] as List).single;
        return _json(component);
      }
      if (request.method == 'GET' && request.url.path.endsWith('/draft-1')) {
        return _json(_draftJson(selected: selected));
      }
      return _json({}, statusCode: 404);
    });
    final repository = AdminOfficialSourcesRepository(
      apiClient: ApiClient(backend, client: client),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OfficialImportReviewPage(
          draft: ImportDraft.fromJson(_draftJson()),
          repository: repository,
          token: 'token',
          tx: tr,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo skill'), findsNothing);
    await tester.tap(find.text('skills (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Demo skill'));
    await tester.pumpAndSettle();

    expect(selected, isTrue);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'Demo skill'),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('un grupo colapsado no construye sus componentes', (
    tester,
  ) async {
    // Distinto de «no se ven»: ExpansionTile ya los ocultaba, pero los
    // construía igual. Con un repositorio oficial de cientos de componentes,
    // eso es toda la pantalla montada para no enseñar nada.
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final repository = AdminOfficialSourcesRepository(
      apiClient: ApiClient(backend, client: MockClient((_) async => _json({}))),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: OfficialImportReviewPage(
          draft: ImportDraft.fromJson(_draftJson()),
          repository: repository,
          token: 'token',
          tx: tr,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.byType(OfficialImportComponentTile, skipOffstage: false);
    expect(tile, findsNothing);

    await tester.tap(find.text('skills (1)'));
    await tester.pumpAndSettle();

    expect(tile, findsOneWidget);
  });

  testWidgets('el log técnico está oculto y se alterna desde su botón', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final repository = AdminOfficialSourcesRepository(
      apiClient: ApiClient(backend, client: MockClient((_) async => _json({}))),
    );
    final json = _draftJson();
    json['security_warnings'] = [
      'La licencia no está reconocida',
      'reviewer: referencia fuera del repositorio (../../guide.md)',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: OfficialImportReviewPage(
          draft: ImportDraft.fromJson(json),
          repository: repository,
          token: 'token',
          tx: tr,
        ),
      ),
    );
    await tester.pumpAndSettle();

    const legacyLog =
        'reviewer: referencia fuera del repositorio (../../guide.md)';
    expect(find.text(legacyLog), findsNothing);
    expect(find.text('La licencia no está reconocida'), findsNothing);
    await tester.tap(find.text('Log (2)'));
    await tester.pump();
    expect(find.text(legacyLog), findsOneWidget);
    expect(find.text('La licencia no está reconocida'), findsOneWidget);
    await tester.tap(find.text('Log (2)'));
    await tester.pump();
    expect(find.text(legacyLog), findsNothing);
    expect(find.text('La licencia no está reconocida'), findsNothing);
  });

  testWidgets('el grafo previo reutiliza el grafo animado de la aplicación', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.endsWith('/relations')) {
        return _json({
          'root': {
            'type': 'official_source',
            'id': 'draft-1',
            'label': 'Demo',
            'description': 'Repositorio',
          },
          'items': [
            {
              'type': 'skill',
              'id': 'demo-skill',
              'label': 'Demo skill',
              'description': 'new · no seleccionado',
              'relation': 'origin',
              'via': null,
            },
          ],
        });
      }
      return _json({}, statusCode: 404);
    });
    final repository = AdminOfficialSourcesRepository(
      apiClient: ApiClient(backend, client: client),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OfficialImportReviewPage(
          draft: ImportDraft.fromJson(_draftJson()),
          repository: repository,
          token: 'token',
          tx: tr,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Grafo previo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AnimatedResourceGraph), findsOneWidget);
    expect(find.text('Demo skill'), findsWidgets);
  });
}

Map<String, dynamic> _draftJson({bool selected = false}) => {
  'id': 'draft-1',
  'draft_id': 'draft-1',
  'status': 'pending',
  'expired': false,
  'source': {
    'id': 'source-1',
    'name': 'Demo',
    'repository_url': 'https://github.com/example/demo',
    'provider': 'github',
    'repository_path': 'example/demo',
    'tracking_mode': 'branch',
    'tracking_ref': 'main',
    'resources': <Object>[],
  },
  'components': [
    {
      'component_id': 'demo-skill',
      'component_type': 'skill',
      'name': 'Demo skill',
      'source_path': 'skills/demo/SKILL.md',
      'state': 'new',
      'selected': selected,
      'materializable': true,
      'dependencies': <Object>[],
      'variants': <Object>[],
    },
  ],
  'errors': <Object>[],
  'security_warnings': <Object>[],
};

http.Response _json(Object body, {int statusCode = 200}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json'},
);
