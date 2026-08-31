import 'api_repository.dart';
import 'cursor_page_collector.dart';
import 'page_result.dart';

/// Repositorio de un recurso con scope: `/api/<recurso>/<scope>/<id>`.
///
/// `skills_repository.dart` y `prompts_repository.dart` eran literalmente el
/// mismo fichero salvo por la palabra «skill»/«prompt», y
/// `tools_repository.dart` solo añadía la subida y descarga del binario. Cada
/// cambio en el contrato —cambiar la codificación del `group_id`, meter
/// paginación— había que aplicarlo tres veces, y ya
/// había divergencia: `agents_repository` codificaba el `group_id` con
/// `Uri.encodeComponent` mientras los otros tres usaban
/// `Uri.encodeQueryComponent`.
///
/// Construir la consulta con `Uri(queryParameters:)` zanja además esa
/// diferencia: el codificado lo decide `Uri`, no cada repositorio.
class ScopedResourceRepository<T> extends ApiRepository {
  const ScopedResourceRepository({
    required super.apiClient,
    required this.basePath,
    required this.parse,
  });

  /// Nombre del recurso en la API: `'skills'`, `'prompts'`, `'tools'`.
  final String basePath;

  /// Convierte cada elemento del listado en su modelo.
  final T Function(Map<String, dynamic>) parse;

  String _path([String? scope, String? id]) => [
    '/api/$basePath',
    if (scope != null) Uri.encodeComponent(scope),
    if (id != null) Uri.encodeComponent(id),
  ].join('/');

  /// Recorre todas las páginas hasta agotarlas.
  ///
  /// Es lo correcto para quien necesita el conjunto completo —los selectores
  /// de skills, prompts y tools de un agente, las sugerencias de `@` del chat,
  /// el catálogo de etiquetas— y para las pestañas de Knowledge, que filtran
  /// por categoría o lenguaje **en cliente**: pedir una página suelta les
  /// dejaría resultados incompletos sin manera de saberlo. Para un listado con
  /// scroll que solo enseña lo visible, usa [listPage] y carga bajo demanda,
  /// como hace la pestaña de Documentos.
  Future<List<T>> list(String token, {String scope = 'all', String? groupId}) =>
      collectCursorPages(
        (cursor) => listPage(
          token,
          scope: scope,
          groupId: groupId,
          limit: 100,
          cursor: cursor,
        ),
      );

  Future<PageResult<T>> listPage(
    String token, {
    String scope = 'all',
    String? groupId,
    int limit = 50,
    String? cursor,
  }) async {
    final uri = Uri(
      path: '/api/v2/$basePath',
      queryParameters: {
        'scope': scope,
        if (groupId != null && groupId.isNotEmpty) 'group_id': groupId,
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final response = await apiClient.get(
      uri.toString(),
      gaToken: token,
      cache: true,
    );
    return PageResult.fromCursorV2Response(response, parse);
  }

  Future<Map<String, dynamic>> get(
    String token,
    String scope,
    String id,
  ) async {
    final response = await apiClient.get(_path(scope, id), gaToken: token);
    return response.json;
  }

  Future<Map<String, dynamic>> save(
    String token,
    String scope,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      _path(scope),
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> remove(String token, String scope, String id) async {
    await apiClient.delete(_path(scope, id), gaToken: token);
  }
}
