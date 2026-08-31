import '../../../core/network/api_repository.dart';

/// Gestión de knowledge desde Admin (`/api/v2/admin/knowledge`): listado y
/// borrado administrativo.
class AdminKnowledgeRepository extends ApiRepository {
  AdminKnowledgeRepository({required super.apiClient});

  Future<void> deleteAdminKnowledge(String token, String itemId) async {
    await apiClient.delete(
      '/api/admin/knowledge/${Uri.encodeComponent(itemId)}',
      gaToken: token,
    );
  }
}
