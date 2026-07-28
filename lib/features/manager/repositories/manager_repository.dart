import '../../../core/network/api_client.dart';
import '../../../models/manager/workspace_models.dart';

class ManagerRepository {
  ManagerRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<WorkspaceItem>> listWorkspaces(String token) async {
    final response = await apiClient.get('/api/workspaces', gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => WorkspaceItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> createWorkspace(String token, String name) async {
    final response = await apiClient.post(
      '/api/workspaces',
      gaToken: token,
      body: {'name': name},
    );
    return response.json;
  }

  Future<Map<String, dynamic>> renameWorkspace(String token, String workspaceId, String name) async {
    final response = await apiClient.patch(
      '/api/workspaces/${Uri.encodeComponent(workspaceId)}',
      gaToken: token,
      body: {'name': name},
    );
    return response.json;
  }

  Future<void> deleteWorkspace(String token, String workspaceId) async {
    await apiClient.delete('/api/workspaces/${Uri.encodeComponent(workspaceId)}', gaToken: token);
  }

  Future<String?> switchWorkspace(String token, String workspaceId) async {
    final response = await apiClient.post(
      '/api/workspaces/switch/${Uri.encodeComponent(workspaceId)}',
      gaToken: token,
    );
    return apiClient.extractGaToken(response.headers);
  }

  Future<List<Map<String, dynamic>>> listMembers(String token, String workspaceId) async {
    final response = await apiClient.get(
      '/api/workspaces/${Uri.encodeComponent(workspaceId)}/members',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> addMember(
    String token,
    String workspaceId, {
    required String username,
    String role = 'member',
  }) async {
    await apiClient.post(
      '/api/workspaces/${Uri.encodeComponent(workspaceId)}/members',
      gaToken: token,
      body: {
        'username': username,
        'role': role,
      },
    );
  }

  Future<void> removeMember(String token, String workspaceId, String username) async {
    await apiClient.delete(
      '/api/workspaces/${Uri.encodeComponent(workspaceId)}/members/${Uri.encodeComponent(username)}',
      gaToken: token,
    );
  }

  Future<List<Map<String, dynamic>>> listInvitations(String token, String workspaceId) async {
    final response = await apiClient.get(
      '/api/workspaces/${Uri.encodeComponent(workspaceId)}/invitations',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> inviteMember(String token, String workspaceId, String username) async {
    await apiClient.post(
      '/api/workspaces/${Uri.encodeComponent(workspaceId)}/invitations',
      gaToken: token,
      body: {'username': username},
    );
  }

  Future<void> cancelInvitation(String token, String workspaceId, String invitationId) async {
    await apiClient.delete(
      '/api/workspaces/${Uri.encodeComponent(workspaceId)}/invitations/${Uri.encodeComponent(invitationId)}',
      gaToken: token,
    );
  }

  /// Invitaciones que YO he recibido (pendientes de aceptar/rechazar),
  /// distintas de las que un grupo ha enviado a otros usuarios.
  Future<List<Map<String, dynamic>>> listMyInvitations(String token) async {
    final response = await apiClient.get('/api/workspaces/my-invitations', gaToken: token);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> acceptInvitation(String token, String invitationId) async {
    await apiClient.post(
      '/api/workspaces/invitations/${Uri.encodeComponent(invitationId)}/accept',
      gaToken: token,
    );
  }

  Future<void> rejectInvitation(String token, String invitationId) async {
    await apiClient.post(
      '/api/workspaces/invitations/${Uri.encodeComponent(invitationId)}/reject',
      gaToken: token,
    );
  }

  Future<void> transferOwnership(String token, String workspaceId, String username) async {
    await apiClient.post(
      '/api/workspaces/${Uri.encodeComponent(workspaceId)}/transfer-ownership',
      gaToken: token,
      body: {'username': username},
    );
  }
}
