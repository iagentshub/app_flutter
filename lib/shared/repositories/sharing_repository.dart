import '../../core/network/api_client.dart';

/// Comparte/descomparte un recurso con uno o varios grupos (workspaces) —
/// un recurso puede estar compartido con varios grupos a la vez
/// (`resource_workspace_shares` es una relación N a N en el backend).
class SharingRepository {
  SharingRepository({required this.apiClient});

  final ApiClient apiClient;

  /// IDs de los grupos que ya tienen acceso al recurso.
  Future<List<String>> listGroups(
    String token, {
    required String resourceType,
    required String resourceId,
  }) async {
    final response = await apiClient.get(
      '/api/sharing/$resourceType/${Uri.encodeComponent(resourceId)}/groups',
      gaToken: token,
    );
    final ids = response.json['group_ids'];
    if (ids is! List) return const [];
    return ids.map((e) => e.toString()).toList();
  }

  Future<void> share(
    String token, {
    required String resourceType,
    required String resourceId,
    required String groupId,
  }) async {
    await apiClient.post(
      '/api/sharing/$resourceType/${Uri.encodeComponent(resourceId)}',
      gaToken: token,
      body: {'group_id': groupId},
    );
  }

  Future<void> unshare(
    String token, {
    required String resourceType,
    required String resourceId,
    required String groupId,
  }) async {
    await apiClient.delete(
      '/api/sharing/$resourceType/${Uri.encodeComponent(resourceId)}?group_id=${Uri.encodeQueryComponent(groupId)}',
      gaToken: token,
    );
  }
}
