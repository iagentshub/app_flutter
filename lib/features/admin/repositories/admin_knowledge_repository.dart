import '../../../core/network/api_repository.dart';

/// Gestión de knowledge desde Admin (`/api/admin/knowledge`): listado y
/// borrado administrativo.
class AdminKnowledgeRepository extends ApiRepository {
  AdminKnowledgeRepository({required super.apiClient});

  Future<List<Map<String, dynamic>>> listAdminKnowledge(String token) async {
    final response = await apiClient.get(
      '/api/admin/knowledge',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> deleteAdminKnowledge(String token, String itemId) async {
    await apiClient.delete(
      '/api/admin/knowledge/${Uri.encodeComponent(itemId)}',
      gaToken: token,
    );
  }
}
