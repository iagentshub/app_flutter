import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/agents/pages/agent_form_page.dart';
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

  testWidgets(
    'mantiene el formulario compacto y busca recursos en un diálogo',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});

      final backend = await BackendController.bootstrap();
      final httpClient = MockClient((request) async {
        if (request.url.path == '/api/skills') {
          return _json([
            for (var index = 0; index < 200; index++)
              {
                'id': 'skill-$index',
                'name': 'Skill $index',
                'category': index.isEven ? 'productividad' : 'desarrollo',
              },
          ]);
        }
        if (request.url.path == '/api/tools') {
          return _json([
            {'id': 'tool-python', 'name': 'Tool Python', 'language': 'python'},
          ]);
        }
        if ({
          '/api/connections',
          '/api/memory',
          '/api/knowledge',
          '/api/prompts',
        }.contains(request.url.path)) {
          return _json([]);
        }
        return _json({}, statusCode: 404);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AgentFormPage(
            apiClient: ApiClient(backend, client: httpClient),
            token: 'agent-form-test-token',
            tx: tr,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Skill 199'), findsNothing);

      await tester.tap(find.text('Conocimiento'));
      await tester.pumpAndSettle();
      expect(find.text('Skills'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('agent-open-resources-picker')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('agent-resources-search')),
        'Tool Python',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('agent-resource-tool-tool-python')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('agent-resource-tool-tool-python')),
          matching: find.text('Herramientas · Python'),
        ),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey('agent-resources-search')),
        'Skill 199',
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('agent-resource-skill-skill-199')),
        findsOneWidget,
      );
      expect(find.text('Skill 0'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('agent-resource-skill-skill-199')),
      );
      await tester.tap(find.byKey(const ValueKey('agent-resources-apply')));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Skill 199'), findsOneWidget);
    },
  );

  testWidgets('la página y el selector caben a 360 px', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});

    final backend = await BackendController.bootstrap();
    final httpClient = MockClient((request) async => _json([]));
    await tester.pumpWidget(
      MaterialApp(
        home: AgentFormPage(
          apiClient: ApiClient(backend, client: httpClient),
          token: 'agent-form-mobile-test-token',
          tx: tr,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(TabBar), const Offset(-180, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conocimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-open-resources-picker')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Recursos del agente'), findsWidgets);
    expect(find.byKey(const ValueKey('agent-resources-apply')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('al publicar pregunta dependencias y nunca ofrece conexiones', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final httpClient = MockClient((request) async {
      if (request.url.path == '/api/skills') {
        return _json([
          {
            'id': 'skill-publicable',
            'name': 'Skill publicable',
            'labels': ['private'],
            'scope': 'private',
          },
        ]);
      }
      if (request.url.path == '/api/connections') {
        return _json([
          {
            'id': 'secret-connection',
            'name': 'Conexión secreta',
            'type': 'openai',
          },
        ]);
      }
      if ({
        '/api/memory',
        '/api/knowledge',
        '/api/prompts',
        '/api/tools',
      }.contains(request.url.path)) {
        return _json([]);
      }
      return _json({}, statusCode: 404);
    });
    Map<String, dynamic>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              Navigator.of(context)
                  .push<Map<String, dynamic>>(
                    MaterialPageRoute(
                      builder: (_) => AgentFormPage(
                        apiClient: ApiClient(backend, client: httpClient),
                        token: 'publish-agent-token',
                        tx: tr,
                        initial: const {
                          'id': 'agent-publicable',
                          'name': 'Agente publicable',
                          'labels': ['public'],
                          'scope': 'public',
                          'connection_id': 'secret-connection',
                          'skills': ['skill-publicable'],
                          'public_dependencies': <String>[],
                        },
                      ),
                    ),
                  )
                  .then((value) => result = value);
            },
            child: const Text('Abrir'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agent-form-save')));
    await tester.pumpAndSettle();

    expect(find.text('Las conexiones nunca se publican.'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Conexión secreta'),
      ),
      findsNothing,
    );
    final skillCheckbox = find.byKey(
      const ValueKey('publish-dependency-skill:skill-publicable'),
    );
    expect(skillCheckbox, findsOneWidget);
    expect(tester.widget<CheckboxListTile>(skillCheckbox).value, isFalse);

    await tester.tap(skillCheckbox);
    await tester.tap(
      find.byKey(const ValueKey('publish-dependencies-confirm')),
    );
    await tester.pumpAndSettle();

    expect(result?['publish_dependencies'], ['skill:skill-publicable']);
    expect(result?['connection_id'], 'secret-connection');
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
