import '../../../core/network/api_repository.dart';

/// Gestión de grupos desde Admin (`/api/v2/admin/groups`): listado, cambio de
/// estado (activo/suspendido) y borrado.
class AdminGroupsRepository extends ApiRepository {
  AdminGroupsRepository({required super.apiClient});

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
