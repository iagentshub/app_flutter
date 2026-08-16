import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/knowledge/pages/knowledge_page.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/app_services_scope.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

// La pestaña de Documentos pagina, pero filtra el origen y el modo packs en
// cliente. Si la primera página no deja nada visible, no hay scroll; y sin
// scroll no llega ninguna ScrollNotification que pida la página siguiente. El
// usuario veía la pestaña vacía con sus documentos esperando en la página dos.

http.Response _json(Object payload, {Map<String, String>? headers}) =>
    http.Response(jsonEncode(payload), 200, headers: {
      'content-type': 'application/json',
      ...?headers,
    });

Map<String, dynamic> _item(String id, {String? packId}) => {
  'id': id,
  'type': 'text',
  'title': 'Documento $id',
  'source': 'test',
  'char_count': 10,
  'labels': ['private'],
  'is_active': true,
  'created_at': '2026-08-16T00:00:00Z',
  'updated_at': '2026-08-16T00:00:00Z',
  'pack_id': packId,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'sigue pidiendo páginas cuando el filtro deja la primera vacía',
    (tester) async {
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

      // Primera página: todo dentro de packs, así que el modo packs —el de
      // entrada— la filtra entera. El documento suelto está en la segunda.
      final offsetsPedidos = <String>[];
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/knowledge') {
          final offset = request.url.queryParameters['offset'] ?? '0';
          offsetsPedidos.add(offset);
          if (offset == '0') {
            return _json(
              [for (var i = 0; i < 5; i++) _item('en-pack-$i', packId: 'p1')],
              headers: {'x-has-more': 'true', 'x-total-count': '6'},
            );
          }
          return _json(
            [_item('suelto')],
            headers: {'x-has-more': 'false', 'x-total-count': '6'},
          );
        }
        if (path == '/api/knowledge/packs') return _json([]);
        if (path == '/api/agents' ||
            path == '/api/skills' ||
            path == '/api/prompts' ||
            path == '/api/tools') {
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
              child: const KnowledgePage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Documentos no es la pestaña de entrada y cada sección se carga al
      // abrirse por primera vez.
      await tester.tap(find.text('Documentos'));
      await tester.pumpAndSettle();

      expect(
        offsetsPedidos,
        containsAll(<String>['0', '5']),
        reason: 'la segunda página no se llegó a pedir: $offsetsPedidos',
      );
      expect(find.text('Documento suelto'), findsOneWidget);
    },
  );
}
