import '../../../core/network/api_repository.dart';

/// Gestión de grupos desde Admin (`/api/admin/groups`): listado, cambio de
/// estado (activo/suspendido) y borrado.
class AdminGroupsRepository extends ApiRepository {
  AdminGroupsRepository({required super.apiClient});

  Future<List<Map<String, dynamic>>> listGroups(String token) async {
    final response = await apiClient.get(
      '/api/admin/groups',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> setGroupStatus(
    String token,
    String groupId,
    String status,
  ) async {
    await apiClient.post(
      '/api/admin/groups/${Uri.encodeComponent(groupId)}/status',
      gaToken: token,
      body: {'status': status},
    );
  }

  Future<void> deleteGroup(String token, String groupId) async {
    await apiClient.delete(
      '/api/admin/groups/${Uri.encodeComponent(groupId)}',
      gaToken: token,
    );
  }
}
