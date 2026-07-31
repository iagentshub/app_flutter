import '../../../core/network/api_repository.dart';
import '../../../models/profile/profile_models.dart';

class ProfileRepository extends ApiRepository {
  ProfileRepository({required super.apiClient});

  Future<ProfileBundle> fetchBundle(String token) async {
    final licenseFuture = _fetchLicense(token);
    final coreResponses = await Future.wait([
      apiClient.get('/api/auth/me', gaToken: token, cache: true),
      apiClient.get('/api/settings', gaToken: token, cache: true),
      apiClient.get(
        '/api/auth/me/deletion-status',
        gaToken: token,
        cache: true,
      ),
    ]);

    final session = ProfileSession.fromJson(coreResponses[0].json);
    final settings = ProfileSettings.fromJson(coreResponses[1].json);
    final deletion = DeletionStatus.fromJson(coreResponses[2].json);

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
      license: await licenseFuture,
    );
  }

  Future<LicenseInfo> _fetchLicense(String token) async {
    try {
      final response = await apiClient.get(
        '/api/billing/subscription',
        gaToken: token,
        cache: true,
      );
      return LicenseInfo.fromJson(response.json);
    } catch (_) {
      // Billing puede no estar disponible en todos los despliegues.
      return const LicenseInfo(tier: 'free');
    }
  }

  Future<ProfileSettings> updateSettings(
    String token, {
    required String theme,
    required String language,
  }) async {
    final response = await apiClient.put(
      '/api/settings',
      gaToken: token,
      body: {'theme': theme, 'language': language},
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
      body: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  Future<String> requestDeletion(String token) async {
    final response = await apiClient.post(
      '/api/auth/me/request-deletion',
      gaToken: token,
    );
    return response.json['message'] as String? ??
        'Cuenta programada para eliminación';
  }
}
