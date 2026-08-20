import '../../../core/network/api_error.dart';
import '../../../core/network/api_repository.dart';
import '../../../models/explore/explore_models.dart';
import '../../../shared/graph/resource_graph_builder.dart';
import '../../../utils/i18n.dart';

/// Relación entre el catálogo y lo que el usuario ya tiene enlazado.
///
/// Los valores son los que acepta el backend (`app/api/routes/explore.py`);
/// enviar otro devuelve 422.
abstract final class ExploreRelation {
  /// Lo que todavía no está en la biblioteca del usuario. Es lo que Explorar
  /// pide por defecto: descubrir es ver lo que no tienes.
  static const nuevo = 'new';

  /// De otros usuarios y ya enlazado.
  static const enlazado = 'linked';

  static const todo = 'all';
}

class ExploreRepository extends ApiRepository {
  ExploreRepository({required super.apiClient});

  Future<List<ExploreItem>> listResources(
    String token, {
    required String type,
    String query = '',
    String category = '',
    List<String> labels = const [],
    List<String> languages = const [],
    bool includeOfficial = true,
    bool? packMode,
    String relation = ExploreRelation.todo,
    int limit = 40,
    int offset = 0,
  }) async {
    final page = await listResourcePage(
      token,
      type: type,
      query: query,
      category: category,
      labels: labels,
      languages: languages,
      includeOfficial: includeOfficial,
      packMode: packMode,
      relation: relation,
      limit: limit,
      offset: offset,
    );
    return page.items;
  }

  /// Una página del catálogo. `linkedMatches` solo llega cuando `relation` es
  /// `new` y la página sale vacía: es lo que el filtro dejó fuera por estar ya
  /// enlazado, y sirve para explicar el vacío sin una segunda petición.
  Future<({List<ExploreItem> items, int total, int linkedMatches})>
  listResourcePage(
    String token, {
    required String type,
    String query = '',
    String category = '',
    List<String> labels = const [],
    List<String> languages = const [],
    bool includeOfficial = true,
    bool? packMode,
    String relation = ExploreRelation.todo,
    int limit = 40,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'type': type,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (category.trim().isNotEmpty) 'category': category.trim(),
      if (labels.isNotEmpty) 'label': labels,
      if (languages.isNotEmpty) 'language': languages,
      if (!includeOfficial) 'include_official': 'false',
      if (packMode != null) 'pack_mode': '$packMode',
      if (relation != ExploreRelation.todo) 'relation': relation,
      'limit': '$limit',
      'offset': '$offset',
    };
    final uri = Uri(path: '/api/explore', queryParameters: params);
    final response = await apiClient.get(
      uri.toString(),
      gaToken: token,
      // El catálogo cambia por acciones de otros usuarios. Una caché local no
      // puede invalidarse cuando otra sesión publica o retira un recurso.
      cache: false,
    );
    final payload = response.body;
    if (payload is! List) {
      return (items: const <ExploreItem>[], total: 0, linkedMatches: 0);
    }
    final items = payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ExploreItem(raw: item))
        .toList();
    final total = int.tryParse(response.headers['x-total-count'] ?? '');
    return (
      items: items,
      total: total ?? offset + items.length,
      linkedMatches:
          int.tryParse(response.headers['x-linked-count'] ?? '') ?? 0,
    );
  }

  Future<List<ExploreOfficialPack>> listOfficialPacks(
    String token, {
    required String type,
    String query = '',
    String category = '',
    List<String> labels = const [],
    List<String> languages = const [],
    String relation = ExploreRelation.todo,
  }) async {
    final params = <String, dynamic>{
      'type': type,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (category.trim().isNotEmpty) 'category': category.trim(),
      if (labels.isNotEmpty) 'label': labels,
      if (languages.isNotEmpty) 'language': languages,
      if (relation != ExploreRelation.todo) 'relation': relation,
    };
    try {
      final response = await apiClient.get(
        Uri(
          path: '/api/explore/official-packs',
          queryParameters: params,
        ).toString(),
        gaToken: token,
        cache: false,
      );
      final payload = response.body;
      if (payload is! List) return const [];
      return payload
          .whereType<Map>()
          .map(
            (item) =>
                ExploreOfficialPack.fromJson(item.cast<String, dynamic>()),
          )
          .where((item) => item.sourceId.isNotEmpty)
          .toList();
    } on ApiError catch (error) {
      // Compatibilidad durante despliegues escalonados Flutter/backend.
      if (error.statusCode == 404) return const [];
      rethrow;
    }
  }

  Future<ExploreOfficialPackDetail> getOfficialPack(
    String token,
    String sourceId,
  ) async {
    final response = await apiClient.get(
      '/api/explore/official-packs/${Uri.encodeComponent(sourceId)}',
      gaToken: token,
    );
    return ExploreOfficialPackDetail.fromJson(response.json);
  }

  Future<GraphBuild> getOfficialPackGraph(String token, String sourceId) async {
    final response = await apiClient.get(
      '/api/explore/official_source/${Uri.encodeComponent(sourceId)}/relations',
      gaToken: token,
    );
    return fromRelations(response.json);
  }

  Future<GraphBuild> getResourceGraph(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.get(
      '/api/explore/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(resourceId)}/relations',
      gaToken: token,
      cache: false,
    );
    return fromRelations(response.json);
  }

  Future<ExploreOfficialPackLinkResult> linkOfficialPack(
    String token,
    String sourceId, {
    required String commitSha,
    List<String>? componentKeys,
  }) async {
    final response = await apiClient.post(
      '/api/explore/official-packs/${Uri.encodeComponent(sourceId)}/link',
      gaToken: token,
      body: {
        'mode': componentKeys == null ? 'all' : 'selected',
        'component_keys': componentKeys ?? const <String>[],
        'commit_sha': commitSha,
      },
    );
    apiClient.invalidateCache('/api/explore');
    return ExploreOfficialPackLinkResult.fromJson(response.json);
  }

  Future<List<ExploreUserItem>> searchUsers(
    String token, {
    String query = '',
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'limit': '$limit',
      'offset': '$offset',
    };
    final uri = Uri(path: '/api/users', queryParameters: params);
    final response = await apiClient.get(uri.toString(), gaToken: token);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ExploreUserItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getPreview(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.get(
      '/api/explore/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(resourceId)}/preview',
      gaToken: token,
    );
    return response.json;
  }

  Future<int> star(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.post(
      '/api/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(resourceId)}/star',
      gaToken: token,
    );
    apiClient.invalidateCache('/api/explore');
    apiClient.invalidateCache('/api/feed');
    final payload = response.json;
    final stars = payload['stars'];
    if (stars is int) return stars;
    if (stars is num) return stars.toInt();
    return 0;
  }

  Future<int> unstar(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.delete(
      '/api/${Uri.encodeComponent(resourceType)}/${Uri.encodeComponent(resourceId)}/star',
      gaToken: token,
    );
    apiClient.invalidateCache('/api/explore');
    apiClient.invalidateCache('/api/feed');
    final payload = response.json;
    final stars = payload['stars'];
    if (stars is int) return stars;
    if (stars is num) return stars.toInt();
    return 0;
  }

  Future<Map<String, dynamic>> linkResource(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    switch (resourceType) {
      case 'knowledge':
        return (await apiClient.post(
          '/api/knowledge/${Uri.encodeComponent(resourceId)}/link',
          gaToken: token,
        )).json;
      case 'workflow':
        return (await apiClient.post(
          '/api/workflows/${Uri.encodeComponent(resourceId)}/link',
          gaToken: token,
        )).json;
      case 'agent':
        return _linkWithScopeFallback(
          token,
          '/api/agents/public/${Uri.encodeComponent(resourceId)}/link',
          '/api/agents/private/${Uri.encodeComponent(resourceId)}/link',
        );
      case 'skill':
        return _linkWithScopeFallback(
          token,
          '/api/skills/public/${Uri.encodeComponent(resourceId)}/link',
          '/api/skills/private/${Uri.encodeComponent(resourceId)}/link',
        );
      case 'prompt':
        return _linkWithScopeFallback(
          token,
          '/api/prompts/public/${Uri.encodeComponent(resourceId)}/link',
          '/api/prompts/private/${Uri.encodeComponent(resourceId)}/link',
        );
      case 'tool':
        return _linkWithScopeFallback(
          token,
          '/api/tools/public/${Uri.encodeComponent(resourceId)}/link',
          '/api/tools/private/${Uri.encodeComponent(resourceId)}/link',
        );
      default:
        throw ApiError(
          statusCode: 422,
          message: '${tr('explore.link_type_unsupported')}: $resourceType',
        );
    }
  }

  Future<Map<String, dynamic>> _linkWithScopeFallback(
    String token,
    String primaryPath,
    String secondaryPath,
  ) async {
    try {
      final response = await apiClient.post(primaryPath, gaToken: token);
      return response.json;
    } on ApiError catch (_) {
      final response = await apiClient.post(secondaryPath, gaToken: token);
      return response.json;
    }
  }
}
