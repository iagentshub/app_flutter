import '../../../core/network/api_client.dart';
import '../../../models/profile/profile_models.dart';

class ProfileRepository {
  ProfileRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<ProfileBundle> fetchBundle(String token) async {
    final sessionResponse = await apiClient.get('/api/auth/me', gaToken: token, cache: true);
    final settingsResponse = await apiClient.get('/api/settings', gaToken: token, cache: true);
    final deletionResponse = await apiClient.get('/api/auth/me/deletion-status', gaToken: token, cache: true);

    final session = ProfileSession.fromJson(sessionResponse.json);
    final settings = ProfileSettings.fromJson(settingsResponse.json);
    final deletion = DeletionStatus.fromJson(deletionResponse.json);

    SocialProfile social = SocialProfile(
      username: session.username,
      languages: const [],
    );

    if (session.username.isNotEmpty) {
      final socialResponse = await apiClient.get(
        '/api/users/${Uri.encodeComponent(session.username)}',
        gaToken: token,
        cache: true,
      );
      social = SocialProfile.fromJson(socialResponse.json);
    }

    return ProfileBundle(
      session: session,
      settings: settings,
      deletion: deletion,
      social: social,
    );
  }

  Future<ProfileSettings> updateSettings(
    String token, {
    required String theme,
    required String language,
  }) async {
    final response = await apiClient.put(
      '/api/settings',
      gaToken: token,
      body: {
        'theme': theme,
        'language': language,
      },
    );
    return ProfileSettings.fromJson(response.json);
  }

  Future<void> updateSocialProfile(
    String token, {
    required String bio,
    required String emailPublic,
    required String github,
    required String cv,
    required List<String> languages,
  }) async {
    await apiClient.put(
      '/api/auth/me/profile',
      gaToken: token,
      body: {
        'bio': bio,
        'email_public': emailPublic,
        'github': github,
        'cv': cv,
        'languages': languages,
      },
    );
  }

  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    await apiClient.post(
      '/api/auth/change-password',
      gaToken: token,
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }

  Future<String> requestDeletion(String token) async {
    final response = await apiClient.post('/api/auth/me/request-deletion', gaToken: token);
    return response.json['message'] as String? ?? 'Cuenta programada para eliminación';
  }
}
