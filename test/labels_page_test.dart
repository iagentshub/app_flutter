import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/labels/cards/label_catalog_card.dart';
import 'package:app_flutter/features/labels/pages/labels_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/labels/label_catalog.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/widgets/explore_search_toolbar.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el catálogo incluye Propietario, Enlace y Fork', () {
    expect(kOwnershipGroup.keys, ['owner', 'linked', 'fork']);
    expect(labelColor('fork'), isNot(labelColor('linked')));
  });

  testWidgets('los grupos del catálogo empiezan cerrados y se despliegan', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: LabelGroupCard(group: kOwnershipGroup, text: tr),
        ),
      ),
    );

    expect(find.text('Propiedad'), findsOneWidget);
    expect(
      find.text("Eres el propietario directo de este recurso."),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('label-group-toggle-labels.group_ownership')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Eres el propietario directo de este recurso."),
      findsOneWidget,
    );
  });

  testWidgets('la búsqueda de etiquetas usa la barra y diálogo comunes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
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
      token: 'user-token',
      user: const SessionUser(id: 'user-1', username: 'ada', role: 'user'),
      remember: false,
    );

    final client = MockClient((request) async {
      if (request.url.path == '/api/agents') {
        return _json([
          {
            'id': 'agent-1',
            'name': 'Agente Español',
            'description': 'Ayuda con textos',
            'labels': ['private', 'lang_es'],
          },
        ]);
      }
      return _json([]);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppServicesScope(
            apiClient: ApiClient(backend, client: client),
            sessionController: session,
            localeController: locale,
            child: const LabelsPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Buscar por etiqueta'));
    await tester.pumpAndSettle();

    expect(find.byType(ExploreSearchToolbar), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.byIcon(Icons.filter_list), findsOneWidget);
    expect(find.byKey(const Key('labelsTypeDropdown')), findsOneWidget);
    expect(find.text('Agente Español'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sin coincidencias');
    await tester.pump();
    expect(find.text('Agente Español'), findsNothing);
    expect(find.text('Sin resultados'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('Propiedad'), findsWidgets);
    expect(find.text('Etiqueta'), findsOneWidget);
  });
}

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}
