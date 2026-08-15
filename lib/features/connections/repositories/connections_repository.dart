import '../../../core/network/api_repository.dart';
import '../../../core/network/page_result.dart';
import '../../../models/connections/connection_models.dart';

class ConnectionsRepository extends ApiRepository {
  ConnectionsRepository({required super.apiClient});

  Future<List<ConnectionItem>> listConnections(
    String token, {
    String? groupId,
    bool includeInactive = false,
    bool cache = true,
  }) async {
    final items = <ConnectionItem>[];
    var offset = 0;
    while (true) {
      final page = await listConnectionPage(
        token,
        groupId: groupId,
        includeInactive: includeInactive,
        cache: cache,
        limit: 100,
        offset: offset,
      );
      items.addAll(page.items);
      if (!page.hasMore || page.items.isEmpty) return items;
      offset += page.items.length;
    }
  }

  Future<PageResult<ConnectionItem>> listConnectionPage(
    String token, {
    String? groupId,
    bool includeInactive = false,
    bool cache = true,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = Uri(
      path: '/api/connections',
      queryParameters: {
        if (groupId != null && groupId.isNotEmpty) 'group_id': groupId,
        if (includeInactive) 'include_inactive': 'true',
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    final response = await apiClient.get(
      uri.toString(),
      gaToken: token,
      cache: cache,
    );
    return PageResult.fromResponse(
      response,
      (item) => ConnectionItem(raw: item),
    );
  }

  Future<Map<String, dynamic>> getConnection(String token, String id) async {
    final response = await apiClient.get(
      '/api/connections/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return response.json;
  }

  Future<List<ConnectionProvider>> listProviders(String token) async {
    final response = await apiClient.get(
      '/api/connections/providers',
      gaToken: token,
      cache: true,
      ttl: const Duration(minutes: 10),
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ConnectionProvider.fromJson(item))
        .toList();
  }

  Future<Map<String, dynamic>> saveConnection(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/connections',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deleteConnection(String token, String id) async {
    await apiClient.delete(
      '/api/connections/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }

  Future<void> setConnectionActive(String token, String id, bool active) =>
      setActive(token, 'connections', id, active);

  Future<ConnectionTestResult> testConnection(String token, String id) async {
    final response = await apiClient.post(
      '/api/connections/${Uri.encodeComponent(id)}/test',
      gaToken: token,
    );
    return ConnectionTestResult.fromJson(response.json);
  }

  /// Modelos instalados en un host Ollama en vivo (`GET {host}/api/tags`),
  /// para rellenar el selector de modelo al dar de alta la conexión sin
  /// tener que escribir el nombre a mano.
  Future<List<String>> fetchOllamaModels(String token, String host) async {
    final response = await apiClient.post(
      '/api/connections/ollama-models',
      gaToken: token,
      body: {'host': host},
    );
    final payload = response.json['models'];
    if (payload is! List) return const [];
    return payload.map((item) => item.toString()).toList();
  }

  /// Sincroniza agentes/skills/conocimiento/conexiones desde otra instancia
  /// de iAgents Hub, para una conexión de tipo `iagentshub`.
  Future<Map<String, dynamic>> syncHub(String token, String id) async {
    final response = await apiClient.post(
      '/api/connections/${Uri.encodeComponent(id)}/hub-sync',
      gaToken: token,
    );
    return response.json;
  }

  Future<List<ConnectionTestResult>> testAllConnections(
    String token, {
    List<String>? ids,
  }) async {
    final body = ids == null || ids.isEmpty
        ? null
        : <String, dynamic>{'ids': ids};
    final response = await apiClient.post(
      '/api/connections/test-all',
      gaToken: token,
      body: body,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ConnectionTestResult.fromJson(item))
        .toList();
  }
}
