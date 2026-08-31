import '../../../core/network/api_repository.dart';

/// Gestión de usuarios desde Admin (`/api/v2/admin/users`): listado con
/// filtros, alta, baja y el `PATCH` genérico que cubre rol/actividad/reset
/// de contraseña.
class AdminUsersRepository extends ApiRepository {
  AdminUsersRepository({required super.apiClient});

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
