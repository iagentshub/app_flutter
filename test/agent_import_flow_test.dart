import 'dart:convert';
import 'dart:typed_data';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/agents/dialogs/agent_directory_import_dialog.dart';
import 'package:app_flutter/features/agents/dialogs/agent_import_preview_dialog.dart';
import 'package:app_flutter/features/agents/pages/agents_page.dart';
import 'package:app_flutter/models/agents/agent_import_models.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/state/upload_limits.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/i18n_de_prueba.dart';
import 'support/memory_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    cargarTraduccionesDePrueba();
    UploadLimits.updateFromPlatform({'max_request_bytes': 0});
  });

  test('interpreta el resumen compacto de una importación de directorio', () {
    final result = AgentDirectoryImportResult.fromJson({
      'agent_count': 2,
      'resource_count': 3,
      'agents': const <Object>[],
      'resources': const <Object>[],
    });

    expect(result.agentCount, 2);
    expect(result.resourceCount, 3);
  });

  testWidgets('el botón + ofrece las cinco vías de creación', (tester) async {
    await _pumpAgentsPage(tester);

    await tester.tap(find.byTooltip('Nuevo agente'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cómo quieres crear el agente?'), findsOneWidget);
    expect(find.text('Desde cero'), findsOneWidget);
    expect(find.text('Desde un archivo'), findsOneWidget);
    expect(find.text('Desde un directorio'), findsOneWidget);
    expect(find.text('A partir de un agente público'), findsOneWidget);
    expect(find.text('Con ayuda de IA'), findsOneWidget);
    expect(find.byType(SimpleDialogOption), findsNWidgets(5));
  });

  testWidgets('el listado principal avanza por cursor al acercarse al final', (
    tester,
  ) async {
    final agentRequests = <Uri>[];
    await _pumpAgentsPage(
      tester,
      onRequest: (request) {
        if (request.url.path == '/api/v2/agents') {
          agentRequests.add(request.url);
          final second = request.url.queryParameters['cursor'] != null;
          return _json({
            'items': [
              for (var index = 0; index < 12; index++)
                {
                  'id': 'agent-${second ? index + 13 : index + 1}',
                  'name': 'Agent ${second ? index + 13 : index + 1}',
                  'scope': 'private',
                },
            ],
            'page': {
              'has_more': !second,
              if (!second) 'next_cursor': 'agents-page-2',
            },
          });
        }
        if (request.url.path == '/api/agents/import/catalog/resolve') {
          return _json({});
        }
        return null;
      },
    );

    expect(agentRequests, hasLength(1));
    expect(agentRequests.single.queryParameters['limit'], '50');
    expect(find.text('Agent 1'), findsOneWidget);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    expect(agentRequests, hasLength(2));
    expect(agentRequests.last.queryParameters['cursor'], 'agents-page-2');
    await tester.scrollUntilVisible(
      find.text('Agent 24'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Agent 24'), findsOneWidget);
  });

  testWidgets(
    'arrastrar un md lo revisa y solo guarda después del formulario',
    (tester) async {
      var previewRequests = 0;
      String? previewMethod;
      Map<String, dynamic>? savedAgent;
      await _pumpAgentsPage(
        tester,
        onRequest: (request) {
          if (request.url.path == '/api/v2/skills') {
            return _json({
              'items': [
                {'id': 'skill-a', 'name': 'A'},
                {'id': 'skill-b', 'name': 'B'},
              ],
              'page': {'has_more': false},
            });
          }
          if (request.url.path == '/api/agents/import/preview') {
            previewRequests++;
            previewMethod = request.method;
            return _json(_previewJson);
          }
          if (request.url.path == '/api/agents' && request.method == 'POST') {
            savedAgent = jsonDecode(request.body) as Map<String, dynamic>;
            return _json({'id': 'agent-imported', ...savedAgent!});
          }
          return null;
        },
      );

      final dropTarget = tester.widget<DropTarget>(find.byType(DropTarget));
      dropTarget.onDragEntered?.call(
        DropEventDetails(
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pump();
      expect(
        find.text('Suelta el archivo para importar el agente'),
        findsOneWidget,
      );

      dropTarget.onDragDone?.call(
        DropDoneDetails(
          files: [
            DropItemFile.fromData(
              Uint8List.fromList(utf8.encode('# prompt')),
              name: 'reviewer.md',
              path: 'reviewer.md',
            ),
          ],
          localPosition: Offset.zero,
          globalPosition: Offset.zero,
        ),
      );
      await tester.pumpAndSettle();

      expect(previewRequests, 1);
      expect(previewMethod, 'POST');
      expect(savedAgent, isNull);
      expect(find.text('Vista previa de importación'), findsOneWidget);
      expect(find.text('Reviewer'), findsOneWidget);
      expect(find.text('Review every change.'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-import-review')));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo agente'), findsWidgets);
      expect(find.widgetWithText(TextFormField, 'Reviewer'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('agent-form-save')));
      await tester.pumpAndSettle();

      expect(savedAgent, isNotNull);
      expect(savedAgent?['name'], 'Reviewer');
      expect(savedAgent?['system_prompt'], 'Review every change.');
      expect(savedAgent?['scope'], 'private');
      expect(savedAgent?['skills'], unorderedEquals(['skill-a', 'skill-b']));
      expect(savedAgent?.containsKey('id'), isFalse);
    },
  );

  testWidgets('cancelar la vista previa no crea ningún agente', (tester) async {
    var saves = 0;
    await _pumpAgentsPage(
      tester,
      onRequest: (request) {
        if (request.url.path == '/api/agents/import/preview') {
          return _json(_previewJson);
        }
        if (request.url.path == '/api/agents' && request.method == 'POST') {
          saves++;
        }
        return null;
      },
    );

    tester
        .widget<DropTarget>(find.byType(DropTarget))
        .onDragDone
        ?.call(
          DropDoneDetails(
            files: [
              DropItemFile.fromData(
                Uint8List.fromList(utf8.encode('prompt')),
                name: 'agent.md',
                path: 'agent.md',
              ),
            ],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(saves, 0);
    expect(find.text('Vista previa de importación'), findsNothing);
  });

  testWidgets('rechaza varios archivos sin llamar a la API', (tester) async {
    var previews = 0;
    await _pumpAgentsPage(
      tester,
      onRequest: (request) {
        if (request.url.path == '/api/agents/import/preview') previews++;
        return null;
      },
    );

    tester
        .widget<DropTarget>(find.byType(DropTarget))
        .onDragDone
        ?.call(
          DropDoneDetails(
            files: [
              DropItemFile.fromData(Uint8List.fromList([1]), path: 'one.md'),
              DropItemFile.fromData(Uint8List.fromList([2]), path: 'two.md'),
            ],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );
    await tester.pump();

    expect(previews, 0);
    expect(find.text('Suelta un único archivo de agente'), findsOneWidget);
  });

  testWidgets('respeta el límite de subida configurado por el administrador', (
    tester,
  ) async {
    UploadLimits.updateFromPlatform({'max_request_bytes': 4});
    var previews = 0;
    await _pumpAgentsPage(
      tester,
      onRequest: (request) {
        if (request.url.path == '/api/agents/import/preview') previews++;
        return null;
      },
    );

    tester
        .widget<DropTarget>(find.byType(DropTarget))
        .onDragDone
        ?.call(
          DropDoneDetails(
            files: [
              DropItemFile.fromData(
                Uint8List.fromList(utf8.encode('12345')),
                path: 'large.md',
              ),
            ],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );
    await tester.pump();

    expect(previews, 0);
    expect(
      find.text('El archivo de agente supera el límite de 4 B'),
      findsOneWidget,
    );
  });

  testWidgets(
    'muestra el límite devuelto por el backend si cambió en caliente',
    (tester) async {
      await _pumpAgentsPage(
        tester,
        onRequest: (request) => request.url.path == '/api/agents/import/preview'
            ? _json({
                'detail': {
                  'code': 'payload_too_large',
                  'message': 'Payload demasiado grande',
                  'limit_bytes': 1536,
                },
              }, statusCode: 413)
            : null,
      );

      tester
          .widget<DropTarget>(find.byType(DropTarget))
          .onDragDone
          ?.call(
            DropDoneDetails(
              files: [
                DropItemFile.fromData(
                  Uint8List.fromList(utf8.encode('prompt')),
                  path: 'agent.md',
                ),
              ],
              localPosition: Offset.zero,
              globalPosition: Offset.zero,
            ),
          );
      await tester.pumpAndSettle();

      expect(
        find.text('El archivo de agente supera el límite de 2 KB'),
        findsOneWidget,
      );
    },
  );

  testWidgets('traduce el motivo estructurado de un JSON inválido', (
    tester,
  ) async {
    await _pumpAgentsPage(
      tester,
      onRequest: (request) => request.url.path == '/api/agents/import/preview'
          ? _json({
              'detail': {
                'code': 'invalid_field',
                'message': 'El JSON no es válido',
                'field': 'file',
                'reason': 'invalid_json',
              },
            }, statusCode: 422)
          : null,
    );

    tester
        .widget<DropTarget>(find.byType(DropTarget))
        .onDragDone
        ?.call(
          DropDoneDetails(
            files: [
              DropItemFile.fromData(
                Uint8List.fromList(utf8.encode('{')),
                path: 'broken.json',
              ),
            ],
            localPosition: Offset.zero,
            globalPosition: Offset.zero,
          ),
        );
    await tester.pumpAndSettle();

    expect(
      find.text('El archivo JSON no contiene un agente válido'),
      findsOneWidget,
    );
    expect(find.text('Vista previa de importación'), findsNothing);
  });

  testWidgets('la vista previa cabe en un móvil de 360 px', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAgentImportPreviewDialog(
              context: context,
              preview: AgentImportPreview.fromJson(_previewJson),
              tx: (path) => tr(path),
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('agent-import-review')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite elegir el recurso cuando el nombre no coincide', (
    tester,
  ) async {
    AgentResourceSelection? result;
    final preview = AgentImportPreview.fromJson({
      ..._previewJson,
      'references': [
        {
          'key': 'skills:0',
          'kind': 'skill',
          'source': 'Nombre externo',
          'status': 'missing',
          'candidates': <Object>[],
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAgentImportPreviewDialog(
                context: context,
                preview: preview,
                resourceOptions: const [
                  AgentResourceOption(
                    id: 'skill-a',
                    type: AgentResourceType.skill,
                    title: 'A',
                  ),
                ],
                tx: (path) => tr(path),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-import-resource-skills:0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-import-review')));
    await tester.pumpAndSettle();

    expect(result?.skillIds, {'skill-a'});
  });

  testWidgets('el selector consulta y pagina un catálogo remoto por tipo', (
    tester,
  ) async {
    final calls = <(AgentResourceType, String, String?)>[];
    final preview = AgentImportPreview.fromJson({
      ..._previewJson,
      'references': [
        {
          'key': 'skills:0',
          'kind': 'skill',
          'source': 'Remota',
          'status': 'missing',
          'candidates': <Object>[],
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showAgentImportPreviewDialog(
              context: context,
              preview: preview,
              tx: (path) => tr(path),
              pageLoader: (type, query, cursor) async {
                calls.add((type, query, cursor));
                return AgentResourceOptionPage(
                  items: [
                    AgentResourceOption(
                      id: cursor == null ? 'remote-a' : 'remote-b',
                      type: type,
                      title: cursor == null ? 'Remota A' : 'Remota B',
                    ),
                  ],
                  hasMore: cursor == null,
                  nextCursor: cursor == null ? 'opaque-1' : null,
                );
              },
            ),
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('agent-import-resource-skills:0')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remota A'), findsOneWidget);
    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();

    expect(find.text('Remota B'), findsOneWidget);
    expect(calls, [
      (AgentResourceType.skill, '', null),
      (AgentResourceType.skill, '', 'opaque-1'),
    ]);
  });

  testWidgets('el directorio permite seleccionar varios agentes y recursos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    AgentDirectoryImportOptions? result;
    final plan = AgentDirectoryImportPlan.fromJson({
      'components': [
        {
          'component_id': 'x',
          'kind': 'agent',
          'name': 'Agent X con un nombre suficientemente largo para móvil',
          'source_path': 'agents/equipo/revisores/especializados/x.md',
          'references': <Object>[],
        },
        {
          'component_id': 'y',
          'kind': 'agent',
          'name': 'Agent Y',
          'source_path': 'agents/y.md',
          'references': <Object>[],
        },
        {
          'component_id': 'a',
          'kind': 'skill',
          'name': 'A',
          'source_path': 'skills/a/SKILL.md',
          'default_action': 'create',
        },
      ],
      'issues': <Object>[],
      'ignored_paths': <Object>[],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showAgentDirectoryImportDialog(
                context: context,
                plan: plan,
                resourceOptions: const [],
                tx: (path) => tr(path),
              );
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    expect(
      find.text('Agent X con un nombre suficientemente largo para móvil'),
      findsOneWidget,
    );
    expect(find.text('Agent Y'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('directory-import-apply')));
    await tester.pumpAndSettle();

    expect(result?.selectedAgentIds, {'x', 'y'});
    expect(result?.componentChoices.single['action'], 'create');
  });
}

Future<void> _pumpAgentsPage(
  WidgetTester tester, {
  http.Response? Function(http.Request request)? onRequest,
}) async {
  tester.view.physicalSize = const Size(1000, 850);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({});

  final backend = await BackendController.bootstrap();
  final locale = await LocaleController.bootstrap();
  final session = await SessionController.bootstrap(
    secureStore: MemorySecureStore(),
  );
  await session.login(
    token: 'agent-import-token',
    user: const SessionUser(id: 'user-1', username: 'ada', role: 'user'),
    remember: false,
  );
  final client = MockClient((request) async {
    final custom = onRequest?.call(request);
    if (custom != null) return custom;
    if (request.url.path.startsWith('/api/v2/')) {
      return _json({
        'items': [],
        'page': {'has_more': false},
      });
    }
    if ({'/api/connections', '/api/memory'}.contains(request.url.path)) {
      return _json([], headers: {'x-has-more': 'false'});
    }
    return _json({});
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AppServicesScope(
          apiClient: ApiClient(backend, client: client),
          sessionController: session,
          localeController: locale,
          child: const AgentsPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

http.Response _json(
  Object body, {
  Map<String, String> headers = const {},
  int statusCode = 200,
}) => http.Response(
  jsonEncode(body),
  statusCode,
  headers: {'content-type': 'application/json', ...headers},
);

const _previewJson = <String, dynamic>{
  'filename': 'reviewer.md',
  'source_format': 'markdown',
  'draft': {
    'name': 'Reviewer',
    'description': 'Reviews code',
    'agent_type': 'generic',
    'model': '',
    'system_prompt': 'Review every change.',
    'temperature': 0.7,
    'scope': 'private',
    'labels': ['private'],
  },
  'issues': <Object>[
    {
      'code': 'resource_references_found',
      'values': ['skills'],
    },
  ],
  'references': <Object>[
    {
      'key': 'skills:0',
      'kind': 'skill',
      'source': 'A',
      'status': 'matched',
      'selected_id': 'skill-a',
      'candidates': [
        {'id': 'skill-a', 'name': 'A'},
      ],
    },
    {
      'key': 'skills:1',
      'kind': 'skill',
      'source': 'B',
      'status': 'matched',
      'selected_id': 'skill-b',
      'candidates': [
        {'id': 'skill-b', 'name': 'B'},
      ],
    },
  ],
  'ignored_fields': <Object>[],
};
