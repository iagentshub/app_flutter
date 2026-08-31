import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/core/network/cursor_pagination_exception.dart';
import 'package:app_flutter/features/admin/repositories/admin_connections_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// El único listado del panel que sobrevive habla el contrato cursor v2. Los
/// otros diez se retiraron con sus rutas: nadie los llamaba.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ApiClient> clienteQueResponde(
    Object cuerpo, {
    void Function(http.Request)? espia,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    return ApiClient(
      backend,
      client: MockClient((request) async {
        espia?.call(request);
        return http.Response(
          jsonEncode(cuerpo),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
  }

  test('el listado de conexiones pide la ruta v2 y lee su página', () async {
    late Uri pedida;
    final repositorio = AdminConnectionsRepository(
      apiClient: await clienteQueResponde({
        'items': [
          {'id': 'c1', 'name': 'Una', 'owner_username': 'ana'},
        ],
        'page': {'limit': 50, 'has_more': true, 'next_cursor': 'siguiente'},
      }, espia: (request) => pedida = request.url),
    );

    final pagina = await repositorio.listAdminConnections('token', limit: 50);

    expect(pedida.path, '/api/v2/admin/connections');
    expect(pedida.queryParameters['limit'], '50');
    expect(pagina.items.single['owner_username'], 'ana');
    expect(pagina.hasMore, isTrue);
    expect(pagina.nextCursor, 'siguiente');
  });

  test('una página que dice tener más sin cursor se rechaza', () async {
    // Aceptarla en silencio devuelve una colección parcial que parece completa,
    // y el selector LLM enseñaría menos conexiones de las que hay.
    final repositorio = AdminConnectionsRepository(
      apiClient: await clienteQueResponde({
        'items': const [],
        'page': {'limit': 50, 'has_more': true, 'next_cursor': null},
      }),
    );

    expect(
      () => repositorio.listAdminConnections('token'),
      throwsA(isA<CursorPaginationException>()),
    );
  });

  test('la respuesta legacy en lista ya no se acepta', () async {
    final repositorio = AdminConnectionsRepository(
      apiClient: await clienteQueResponde([
        {'id': 'c1', 'name': 'Una'},
      ]),
    );

    expect(
      () => repositorio.listAdminConnections('token'),
      throwsA(isA<CursorPaginationException>()),
    );
  });
}
