import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/admin/models/official_import_models.dart';
import 'package:app_flutter/features/admin/pages/official_import_review_page.dart';
import 'package:app_flutter/features/admin/repositories/admin_official_sources_repository.dart';
import 'package:app_flutter/shared/graph/animated_resource_graph.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    expect(diff.counts['delete'], 3);
    expect(origin.sourcePath, 'skills/demo/SKILL.md');
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
        final offset = int.parse(request.url.queryParameters['offset']!);
        final length = offset == 0 ? 500 : 1;
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
              tx: (_, fallback) => fallback,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tile = tester.widget<CheckboxListTile>(
          find.widgetWithText(CheckboxListTile, 'Demo skill'),
        );
        expect(tile.value, isFalse);
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );

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
          tx: (_, fallback) => fallback,
        ),
      ),
    );
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
      if (request.method == 'GET' && request.url.path.endsWith('/graph')) {
        return _json({
          'root_id': 'source',
          'nodes': [
            {
              'id': 'source',
              'label': 'Demo',
              'type': 'official_source',
              'description': 'Repositorio',
            },
            {
              'id': 'demo-skill',
              'label': 'Demo skill',
              'type': 'skill',
              'description': 'new · no seleccionado',
            },
          ],
          'edges': [
            {'source_id': 'source', 'target_id': 'demo-skill', 'dashed': false},
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
          tx: (_, fallback) => fallback,
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
