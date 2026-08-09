import '../../../core/network/api_repository.dart';

class AdminOfficialPackagesRepository extends ApiRepository {
  AdminOfficialPackagesRepository({required super.apiClient});

  Future<List<Map<String, dynamic>>> list(String token) async {
    final response = await apiClient.get(
      '/api/admin/official-packages',
      gaToken: token,
    );
    final payload = response.body;
    return payload is List
        ? payload.whereType<Map<String, dynamic>>().toList()
        : const [];
  }

  /// Devuelve el resultado del sync implícito (`changed`, `package`,
  /// `version` con sus componentes) para poder elegir qué se publica sin
  /// tener que recargar la lista antes.
  Future<Map<String, dynamic>> importRepository(
    String token,
    String repositoryUrl, {
    String trackingMode = 'release',
  }) async {
    final response = await apiClient.post(
      '/api/admin/official-packages/import',
      gaToken: token,
      body: {
        'repository_url': repositoryUrl,
        'tracking_mode': trackingMode,
        'tracking_ref': 'main',
      },
    );
    return response.json;
  }

  Future<Map<String, dynamic>> sync(String token, String packageId) async {
    final response = await apiClient.post(
      '/api/admin/official-packages/${Uri.encodeComponent(packageId)}/sync',
      gaToken: token,
    );
    return response.json;
  }

  Future<void> updatePackage(
    String token,
    String packageId,
    Map<String, dynamic> payload,
  ) async {
    await apiClient.put(
      '/api/admin/official-packages/${Uri.encodeComponent(packageId)}',
      gaToken: token,
      body: payload,
    );
    apiClient.invalidateCache('/api/official-packages');
  }

  Future<void> deletePackage(String token, String packageId) async {
    await apiClient.delete(
      '/api/admin/official-packages/${Uri.encodeComponent(packageId)}',
      gaToken: token,
    );
    apiClient.invalidateCache('/api/official-packages');
    apiClient.invalidateCache('/api/official-packages/copies');
  }

  Future<Map<String, dynamic>> diff(
    String token,
    String packageId,
    String version,
  ) async {
    final response = await apiClient.get(
      '/api/admin/official-packages/${Uri.encodeComponent(packageId)}/versions/${Uri.encodeComponent(version)}/diff',
      gaToken: token,
    );
    return response.json;
  }

  Future<void> review(
    String token,
    String packageId,
    String version, {
    required bool publish,
    Set<String> componentIds = const {},
  }) async {
    final action = publish ? 'publish' : 'reject';
    await apiClient.post(
      '/api/admin/official-packages/${Uri.encodeComponent(packageId)}/versions/${Uri.encodeComponent(version)}/$action',
      gaToken: token,
      body: publish ? {'component_ids': componentIds.toList()} : null,
    );
    apiClient.invalidateCache('/api/official-packages');
    // Publicar puede retirar componentes, y con ellos los recursos enlazados
    // en las cuentas: el catálogo y el inventario de admin quedan obsoletos.
    apiClient.invalidateCache('/api/official-packages/copies');
    apiClient.invalidateCache('/api/explore');
    apiClient.invalidateCache('/api/admin/explore');
  }
}
