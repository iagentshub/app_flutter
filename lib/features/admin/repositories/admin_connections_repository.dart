import '../../../core/network/api_repository.dart';

/// Gestión de conexiones desde Admin (`/api/admin/connections`): listado y
/// borrado administrativo (sin pasar por el dueño de la conexión).
class AdminConnectionsRepository extends ApiRepository {
  AdminConnectionsRepository({required super.apiClient});

  Future<List<Map<String, dynamic>>> listAdminConnections(String token) async {
    final response = await apiClient.get(
      '/api/admin/connections',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> deleteAdminConnection(String token, String connectionId) async {
    await apiClient.delete(
      '/api/admin/connections/${Uri.encodeComponent(connectionId)}',
      gaToken: token,
    );
  }
}
