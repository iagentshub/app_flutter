import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/explore/pages/explore_page.dart';
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

/// Explorar sirve para descubrir: por defecto enseña lo que el usuario todavía
/// no tiene. Lo ya enlazado se consulta a propósito, desde el filtro.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppServicesScope> montar(
    WidgetTester tester,
    http.Client client, {
    Size size = const Size(1000, 1200),
  }) async {
    tester.view.physicalSize = size;
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
    final scope = AppServicesScope(
      apiClient: ApiClient(backend, client: client),
      sessionController: session,
      localeController: locale,
      child: const ExplorePage(),
    );
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: scope)));
    await tester.pumpAndSettle();
    return scope;
  }

  testWidgets('el catálogo pide solo lo que el usuario no tiene', (
    tester,
  ) async {
    final relaciones = <String?>[];
    final client = MockClient((request) async {
      if (request.url.path == '/api/v2/explore') {
        relaciones.add(request.url.queryParameters['relation']);
        return _page([_recurso('agent-nuevo', 'Agente nuevo')]);
      }
      if (request.url.path == '/api/explore/official-packs') {
        relaciones.add(request.url.queryParameters['relation']);
        return _json([]);
      }
      if (request.url.path == '/api/v2/users') return _page([]);
      return _json({}, statusCode: 404);
    });

    await montar(tester, client);

    expect(relaciones, isNotEmpty);
    expect(relaciones.every((relacion) => relacion == 'new'), isTrue);
  });

  testWidgets('el filtro de relación cambia a lo ya enlazado', (tester) async {
    String? ultimaRelacion;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v2/explore') {
        ultimaRelacion = request.url.queryParameters['relation'];
        return _page([
          if (ultimaRelacion == 'linked')
            _recurso('agent-mio', 'Agente ya enlazado', linkedByMe: true)
          else
            _recurso('agent-nuevo', 'Agente nuevo'),
        ]);
      }
      if (request.url.path == '/api/explore/official-packs') return _json([]);
      if (request.url.path == '/api/v2/users') return _page([]);
      return _json({}, statusCode: 404);
    });

    await montar(tester, client);
    expect(find.text('Agente nuevo'), findsOneWidget);
    expect(find.text('Enlazado'), findsNothing);

    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    expect(find.text('Relación'), findsOneWidget);
    await tester.tap(find.text('Enlazados'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();

    expect(ultimaRelacion, 'linked');
    expect(find.text('Agente ya enlazado'), findsOneWidget);
    // El estado se lee de la fila, no de lo que se enlazó en esta sesión.
    expect(find.text('Enlazado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('un vacío causado por el filtro se explica y ofrece salida', (
    tester,
  ) async {
    String? ultimaRelacion;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v2/explore') {
        ultimaRelacion = request.url.queryParameters['relation'];
        if (ultimaRelacion == 'linked') {
          return _page([
            _recurso('agent-mio', 'Agente ya enlazado', linkedByMe: true),
          ]);
        }
        // Vacío, pero el backend cuenta lo que dejó fuera.
        return _page([], linkedMatches: 4);
      }
      if (request.url.path == '/api/explore/official-packs') return _json([]);
      if (request.url.path == '/api/v2/users') return _page([]);
      return _json({}, statusCode: 404);
    });

    await montar(tester, client);

    expect(
      find.text('Ya tienes los 4 resultados de esta búsqueda.'),
      findsOneWidget,
    );
    expect(find.text('No hay resultados para ese filtro.'), findsNothing);

    await tester.tap(find.text('Ver los enlazados'));
    await tester.pumpAndSettle();
    expect(ultimaRelacion, 'linked');
    expect(find.text('Agente ya enlazado'), findsOneWidget);
  });

  testWidgets('los tres segmentos caben en el diálogo a 360 px', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v2/explore') {
        return _page([_recurso('agent-nuevo', 'Agente nuevo')]);
      }
      if (request.url.path == '/api/explore/official-packs') return _json([]);
      if (request.url.path == '/api/v2/users') return _page([]);
      return _json({}, statusCode: 404);
    });

    await montar(tester, client, size: const Size(360, 800));
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('exploreRelationSelector')), findsOneWidget);
    for (final etiqueta in ['Nuevos', 'Enlazados', 'Todos']) {
      expect(find.text(etiqueta), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin coincidencias enlazadas el vacío se queda como estaba', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v2/explore') return _page([]);
      if (request.url.path == '/api/explore/official-packs') return _json([]);
      if (request.url.path == '/api/v2/users') return _page([]);
      return _json({}, statusCode: 404);
    });

    await montar(tester, client);

    expect(find.text('No hay resultados para ese filtro.'), findsOneWidget);
    expect(find.text('Ver los enlazados'), findsNothing);
  });
}

Map<String, dynamic> _recurso(
  String id,
  String nombre, {
  bool linkedByMe = false,
}) => {
  'resource_type': 'agent',
  'resource_id': id,
  'name': nombre,
  'description': '',
  'category': '',
  'labels': ['public'],
  'owner_username': 'grace',
  'stars_count': 0,
  'linked_by_me': linkedByMe,
};

http.Response _json(Object body, {int statusCode = 200}) {
  return http.Response(
    jsonEncode(body),
    statusCode,
    headers: {'content-type': 'application/json'},
  );
}

http.Response _page(List<Object?> items, {int linkedMatches = 0}) => _json({
  'items': items,
  'page': {
    'limit': 40,
    'has_more': false,
    'next_cursor': null,
    'total': items.length,
  },
  'linked_matches': linkedMatches,
});
