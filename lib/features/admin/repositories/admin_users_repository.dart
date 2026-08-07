import '../../../core/network/api_repository.dart';

/// Gestión de usuarios desde Admin (`/api/admin/users`): listado con
/// filtros, alta, baja y el `PATCH` genérico que cubre rol/actividad/reset
/// de contraseña.
class AdminUsersRepository extends ApiRepository {
  AdminUsersRepository({required super.apiClient});

  Future<List<Map<String, dynamic>>> listUsers(
    String token, {
    String query = '',
    String role = '',
    String active = '',
    String verified = '',
  }) async {
    final params = <String, String>{
      if (query.trim().isNotEmpty) 'q': query.trim(),
      if (role.trim().isNotEmpty) 'role': role.trim(),
      if (active.trim().isNotEmpty) 'active': active.trim(),
      if (verified.trim().isNotEmpty) 'verified': verified.trim(),
    };
    final path = Uri(
      path: '/api/admin/users',
      queryParameters: params,
    ).toString();
    final response = await apiClient.get(path, gaToken: token, cache: true);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> patchUser(
    String token,
    String username, {
    String? role,
    bool? isActive,
    String? password,
  }) async {
    await apiClient.patch(
      '/api/admin/users/${Uri.encodeComponent(username)}',
      gaToken: token,
      body: {
        'role': ?role,
        'is_active': ?isActive,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
  }

  Future<void> setUserActive(
    String token,
    String username,
    bool isActive,
  ) async {
    await patchUser(token, username, isActive: isActive);
  }

  Future<void> createUser(
    String token, {
    required String username,
    required String email,
    required String password,
    String? displayName,
    String role = 'standard',
  }) async {
    await apiClient.post(
      '/api/admin/users',
      gaToken: token,
      body: {
        'username': username.trim().toLowerCase(),
        'email': email,
        'password': password,
        if (displayName != null && displayName.isNotEmpty)
          'display_name': displayName,
        'role': role,
      },
    );
  }

  Future<void> deleteUser(String token, String username) async {
    await apiClient.delete(
      '/api/admin/users/${Uri.encodeComponent(username)}',
      gaToken: token,
    );
  }
}
