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
    http.Response(
      jsonEncode(payload),
      200,
      headers: {'content-type': 'application/json', ...?headers},
    );

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

  testWidgets('sigue pidiendo páginas cuando el filtro deja la primera vacía', (
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

    // Primera página: todo dentro de packs, así que el modo packs —el de
    // entrada— la filtra entera. El documento suelto está en la segunda.
    final cursorsPedidos = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path == '/api/v2/knowledge') {
        final cursor = request.url.queryParameters['cursor'] ?? 'first';
        cursorsPedidos.add(cursor);
        if (cursor == 'first') {
          return _json({
            'items': [
              for (var i = 0; i < 5; i++) _item('en-pack-$i', packId: 'p1'),
            ],
            'page': {'has_more': true, 'next_cursor': 'page-2'},
          });
        }
        return _json({
          'items': [_item('suelto')],
          'page': {'has_more': false},
        });
      }
      if (path == '/api/v2/knowledge-packs' ||
          path == '/api/v2/agents' ||
          path == '/api/v2/skills' ||
          path == '/api/v2/prompts' ||
          path == '/api/v2/tools') {
        return _json({
          'items': [],
          'page': {'has_more': false},
        });
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
      cursorsPedidos,
      containsAll(<String>['first', 'page-2']),
      reason: 'la segunda página no se llegó a pedir: $cursorsPedidos',
    );
    expect(find.text('Documento suelto'), findsOneWidget);
  });
}
