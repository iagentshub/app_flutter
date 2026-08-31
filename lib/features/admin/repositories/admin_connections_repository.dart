import '../../../core/network/api_repository.dart';
import '../../../core/network/cursor_page_collector.dart';
import '../../../core/network/page_result.dart';
import '../models/official_import_models.dart';

/// Gestión de conexiones desde Admin (`/api/v2/admin/connections`): listado y
/// borrado administrativo (sin pasar por el dueño de la conexión).
class AdminConnectionsRepository extends ApiRepository {
  AdminConnectionsRepository({required super.apiClient});

  Future<PageResult<Map<String, dynamic>>> listAdminConnections(
    String token, {
    String? cursor,
    int limit = 50,
    String? query,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'cursor': ?cursor,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final path = Uri(
      path: '/api/v2/admin/connections',
      queryParameters: params,
    ).toString();
    final response = await apiClient.get(path, gaToken: token);
    return PageResult<Map<String, dynamic>>.fromCursorV2Response(
      response,
      (item) => item,
    );
  }

  Future<List<OfficialImportLlmConnection>> listLlmConnections(
    String token,
  ) async {
    // La importación oficial necesita el catálogo entero, no una página:
    // una conexión compatible que se quedara fuera del corte no aparecería
    // como opción y nadie sabría por qué. Ver `collectCursorPages`.
    final values = await collectCursorPages<Map<String, dynamic>>(
      (cursor) => listAdminConnections(token, cursor: cursor, limit: 100),
    );
    return values
        .where((item) => item['is_active'] != false)
        .map(OfficialImportLlmConnection.fromJson)
        .where((item) => item.compatible)
        .toList(growable: false);
  }

  Future<void> deleteAdminConnection(String token, String connectionId) async {
    await apiClient.delete(
      '/api/admin/connections/${Uri.encodeComponent(connectionId)}',
      gaToken: token,
    );
  }
}
