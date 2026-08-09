import '../../../core/network/api_repository.dart';

/// Fuentes oficiales del panel de administración.
///
/// Lo que una fuente trae son recursos normales del hub, así que sincronizar
/// invalida también el catálogo y el inventario: lo que se deja de marcar
/// desaparece de golpe.
class AdminOfficialSourcesRepository extends ApiRepository {
  AdminOfficialSourcesRepository({required super.apiClient});

  Future<List<Map<String, dynamic>>> list(String token) async {
    final response = await apiClient.get(
      '/api/admin/official-sources',
      gaToken: token,
    );
    final payload = response.body;
    return payload is List
        ? payload.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  /// Alta de la fuente + primera descarga. Devuelve sus componentes para que
  /// el admin elija qué se queda, sin materializar nada todavía.
  Future<Map<String, dynamic>> importRepository(
    String token,
    String repositoryUrl, {
    String trackingMode = 'release',
  }) async {
    final response = await apiClient.post(
      '/api/admin/official-sources/import',
      gaToken: token,
      body: {
        'repository_url': repositoryUrl,
        'tracking_mode': trackingMode,
        'tracking_ref': 'main',
      },
    );
    _invalidate();
    return response.json;
  }

  /// Sin [componentIds] solo mira qué trae la fuente; con lista, esa pasa a
  /// ser exactamente la selección materializada.
  Future<Map<String, dynamic>> sync(
    String token,
    String sourceId, {
    Set<String>? componentIds,
  }) async {
    final response = await apiClient.post(
      '/api/admin/official-sources/${Uri.encodeComponent(sourceId)}/sync',
      gaToken: token,
      body: componentIds == null
          ? null
          : {'component_ids': componentIds.toList()},
    );
    if (componentIds != null) _invalidate();
    return response.json;
  }

  Future<void> updateSource(
    String token,
    String sourceId,
    Map<String, dynamic> payload,
  ) async {
    await apiClient.put(
      '/api/admin/official-sources/${Uri.encodeComponent(sourceId)}',
      gaToken: token,
      body: payload,
    );
    _invalidate();
  }

  Future<Map<String, dynamic>> deleteSource(
    String token,
    String sourceId,
  ) async {
    final response = await apiClient.delete(
      '/api/admin/official-sources/${Uri.encodeComponent(sourceId)}',
      gaToken: token,
    );
    _invalidate();
    return response.json;
  }

  /// Marca (o desmarca) como oficial un recurso que no viene de ningún
  /// repositorio.
  Future<Map<String, dynamic>> markOfficial(
    String token, {
    required String resourceType,
    required String resourceId,
    required bool official,
  }) async {
    final response = await apiClient.post(
      '/api/admin/resources/${Uri.encodeComponent(resourceType)}/'
      '${Uri.encodeComponent(resourceId)}/official',
      gaToken: token,
      body: {'official': official},
    );
    _invalidate();
    return response.json;
  }

  void _invalidate() {
    apiClient.invalidateCache('/api/admin/official-sources');
    apiClient.invalidateCache('/api/explore');
    apiClient.invalidateCache('/api/admin/explore');
  }
}
