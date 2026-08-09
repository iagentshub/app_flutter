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

  Future<void> importRepository(
    String token,
    String repositoryUrl, {
    String trackingMode = 'release',
  }) async {
    await apiClient.post(
      '/api/admin/official-packages/import',
      gaToken: token,
      body: {
        'repository_url': repositoryUrl,
        'tracking_mode': trackingMode,
        'tracking_ref': 'main',
      },
    );
  }

  Future<void> sync(String token, String packageId) async {
    await apiClient.post(
      '/api/admin/official-packages/${Uri.encodeComponent(packageId)}/sync',
      gaToken: token,
    );
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
  }
}
