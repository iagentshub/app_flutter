import '../../core/network/api_client.dart';

/// Comparte (o quita de) un recurso con un grupo (workspace), equivalente al
/// drag&drop sobre GroupPanel en frontend_vanilla. group_id null = quitar
/// de cualquier grupo (vuelve a ser solo del propietario).
class SharingRepository {
  SharingRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<void> share(
    String token, {
    required String resourceType,
    required String resourceId,
    required String? groupId,
  }) async {
    await apiClient.post(
      '/api/sharing/$resourceType/${Uri.encodeComponent(resourceId)}',
      gaToken: token,
      body: {'group_id': groupId},
    );
  }
}
