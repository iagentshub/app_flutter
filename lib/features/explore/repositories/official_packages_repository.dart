import 'dart:typed_data';

import '../../../core/network/api_repository.dart';
import '../../../models/official_packages/official_package_models.dart';

class OfficialPackagesRepository extends ApiRepository {
  OfficialPackagesRepository({required super.apiClient});

  Future<List<OfficialPackageItem>> list(String token) async {
    final response = await apiClient.get(
      '/api/official-packages',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => OfficialPackageItem(raw: item))
        .toList();
  }

  Future<OfficialPackageDetail> get(String token, String id) async {
    final response = await apiClient.get(
      '/api/official-packages/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return OfficialPackageDetail(raw: response.json);
  }

  Future<List<OfficialPackageCopy>> listCopies(String token) async {
    final response = await apiClient.get(
      '/api/official-packages/copies',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => OfficialPackageCopy(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> copy(
    String token,
    String id,
    Set<String> componentIds,
  ) async {
    final response = await apiClient.post(
      '/api/official-packages/${Uri.encodeComponent(id)}/copy',
      gaToken: token,
      body: {'component_ids': componentIds.toList()},
    );
    apiClient.invalidateCache('/api/skills');
    apiClient.invalidateCache('/api/agents');
    apiClient.invalidateCache('/api/knowledge');
    apiClient.invalidateCache('/api/prompts');
    apiClient.invalidateCache('/api/tools');
    apiClient.invalidateCache('/api/workflows');
    apiClient.invalidateCache('/api/official-packages/copies');
    return response.json;
  }

  Future<Map<String, dynamic>> previewExport(
    String token,
    String id,
    String target,
    Set<String> componentIds,
  ) async {
    final response = await apiClient.post(
      '/api/official-packages/${Uri.encodeComponent(id)}/export-preview',
      gaToken: token,
      body: {'target': target, 'component_ids': componentIds.toList()},
    );
    return response.json;
  }

  Future<({Uint8List bytes, String? filename})> export(
    String token,
    String id,
    String target,
    Set<String> componentIds,
  ) => apiClient.postBytes(
    '/api/official-packages/${Uri.encodeComponent(id)}/export/${Uri.encodeComponent(target)}',
    gaToken: token,
    body: {'component_ids': componentIds.toList()},
  );
}
