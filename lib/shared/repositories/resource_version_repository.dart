import '../../core/network/api_repository.dart';
import '../../models/common/resource_version.dart';

/// Historial de versiones de un recurso editable (solo agentes y skills,
/// que es lo que soporta el backend en /api/resources/{tipo}/{id}/versions).
/// Los snapshots se crean solos en el backend en cada guardado — aquí solo
/// se listan, consultan y restauran.
class ResourceVersionRepository extends ApiRepository {
  ResourceVersionRepository({required super.apiClient});

  Future<List<ResourceVersionItem>> listVersions(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.get(
      '/api/resources/$resourceType/${Uri.encodeComponent(resourceId)}/versions',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => ResourceVersionItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> restoreVersion(
    String token, {
    required String resourceType,
    required String resourceId,
    required int version,
  }) async {
    final response = await apiClient.post(
      '/api/resources/$resourceType/${Uri.encodeComponent(resourceId)}/versions/$version/restore',
      gaToken: token,
    );
    return response.json;
  }
}
