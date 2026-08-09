import 'dart:typed_data';

import '../../../core/network/api_repository.dart';

class OfficialResourceActionsRepository extends ApiRepository {
  OfficialResourceActionsRepository({required super.apiClient});

  Future<Map<String, dynamic>> copy(
    String token,
    String packageId,
    Set<String> componentIds,
  ) async {
    final response = await apiClient.post(
      '/api/official-packages/${Uri.encodeComponent(packageId)}/copy',
      gaToken: token,
      body: {'component_ids': componentIds.toList()},
    );
    apiClient.invalidateCache('/api/skills');
    apiClient.invalidateCache('/api/agents');
    apiClient.invalidateCache('/api/knowledge');
    apiClient.invalidateCache('/api/prompts');
    apiClient.invalidateCache('/api/tools');
    apiClient.invalidateCache('/api/workflows');
    return response.json;
  }

  Future<Map<String, dynamic>> previewExport(
    String token,
    String packageId,
    String target,
    Set<String> componentIds,
  ) async {
    final response = await apiClient.post(
      '/api/official-packages/${Uri.encodeComponent(packageId)}/export-preview',
      gaToken: token,
      body: {'target': target, 'component_ids': componentIds.toList()},
    );
    return response.json;
  }

  Future<({Uint8List bytes, String? filename})> export(
    String token,
    String packageId,
    String target,
    Set<String> componentIds,
  ) => apiClient.postBytes(
    '/api/official-packages/${Uri.encodeComponent(packageId)}/export/${Uri.encodeComponent(target)}',
    gaToken: token,
    body: {'component_ids': componentIds.toList()},
  );
}
