import '../../../core/network/api_repository.dart';
import '../../../models/manager/group_models.dart';

class ManagerRepository extends ApiRepository {
  ManagerRepository({required super.apiClient});

  Future<List<GroupItem>> listGroups(String token) async {
    final response = await apiClient.get(
      '/api/groups',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => GroupItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> createGroup(String token, String name) async {
    final response = await apiClient.post(
      '/api/groups',
      gaToken: token,
      body: {'name': name},
    );
    return response.json;
  }

  Future<Map<String, dynamic>> renameGroup(
    String token,
    String groupId,
    String name,
  ) async {
    final response = await apiClient.patch(
      '/api/groups/${Uri.encodeComponent(groupId)}',
      gaToken: token,
      body: {'name': name},
    );
    return response.json;
  }

  Future<void> deleteGroup(String token, String groupId) async {
    await apiClient.delete(
      '/api/groups/${Uri.encodeComponent(groupId)}',
      gaToken: token,
    );
  }

  Future<String?> switchGroup(String token, String groupId) async {
    final response = await apiClient.post(
      '/api/groups/switch/${Uri.encodeComponent(groupId)}',
      gaToken: token,
    );
    return apiClient.extractGaToken(response.headers);
  }

  Future<List<Map<String, dynamic>>> listMembers(
    String token,
    String groupId,
  ) async {
    final response = await apiClient.get(
      '/api/groups/${Uri.encodeComponent(groupId)}/members',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> addMember(
    String token,
    String groupId, {
    required String username,
    String role = 'member',
  }) async {
    await apiClient.post(
      '/api/groups/${Uri.encodeComponent(groupId)}/members',
      gaToken: token,
      body: {'username': username, 'role': role},
    );
  }

  Future<void> removeMember(
    String token,
    String groupId,
    String username,
  ) async {
    await apiClient.delete(
      '/api/groups/${Uri.encodeComponent(groupId)}/members/${Uri.encodeComponent(username)}',
      gaToken: token,
    );
  }

  Future<List<Map<String, dynamic>>> listInvitations(
    String token,
    String groupId,
  ) async {
    final response = await apiClient.get(
      '/api/groups/${Uri.encodeComponent(groupId)}/invitations',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> inviteMember(
    String token,
    String groupId,
    String username,
  ) async {
    await apiClient.post(
      '/api/groups/${Uri.encodeComponent(groupId)}/invitations',
      gaToken: token,
      body: {'username': username},
    );
  }

  Future<void> cancelInvitation(
    String token,
    String groupId,
    String invitationId,
  ) async {
    await apiClient.delete(
      '/api/groups/${Uri.encodeComponent(groupId)}/invitations/${Uri.encodeComponent(invitationId)}',
      gaToken: token,
    );
  }

  /// Invitaciones que YO he recibido (pendientes de aceptar/rechazar),
  /// distintas de las que un grupo ha enviado a otros usuarios.
  Future<List<Map<String, dynamic>>> listMyInvitations(String token) async {
    final response = await apiClient.get(
      '/api/groups/my-invitations',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> acceptInvitation(String token, String invitationId) async {
    await apiClient.post(
      '/api/groups/invitations/${Uri.encodeComponent(invitationId)}/accept',
      gaToken: token,
    );
  }

  Future<void> rejectInvitation(String token, String invitationId) async {
    await apiClient.post(
      '/api/groups/invitations/${Uri.encodeComponent(invitationId)}/reject',
      gaToken: token,
    );
  }

  Future<void> transferOwnership(
    String token,
    String groupId,
    String username,
  ) async {
    await apiClient.post(
      '/api/groups/${Uri.encodeComponent(groupId)}/transfer-ownership',
      gaToken: token,
      body: {'username': username},
    );
  }
}
