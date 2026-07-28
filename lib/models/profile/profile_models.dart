class ProfileSession {
  const ProfileSession({
    required this.username,
    required this.role,
    this.workspaceId,
    this.workspaceName,
    this.authMethod,
  });

  final String username;
  final String role;
  final String? workspaceId;
  final String? workspaceName;
  final String? authMethod;

  factory ProfileSession.fromJson(Map<String, dynamic> json) {
    return ProfileSession(
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      workspaceId: json['workspace_id'] as String?,
      workspaceName: json['workspace_name'] as String?,
      authMethod: json['auth_method'] as String?,
    );
  }
}

class ProfileSettings {
  const ProfileSettings({
    required this.theme,
    required this.language,
  });

  final String theme;
  final String language;

  factory ProfileSettings.fromJson(Map<String, dynamic> json) {
    return ProfileSettings(
      theme: json['theme'] as String? ?? 'dark-red',
      language: json['language'] as String? ?? 'es',
    );
  }
}

class DeletionStatus {
  const DeletionStatus({
    required this.scheduled,
    this.deletionDate,
  });

  final bool scheduled;
  final String? deletionDate;

  factory DeletionStatus.fromJson(Map<String, dynamic> json) {
    return DeletionStatus(
      scheduled: json['scheduled'] == true,
      deletionDate: json['deletion_date'] as String?,
    );
  }
}

class SocialProfile {
  const SocialProfile({
    required this.username,
    this.bio,
    this.emailPublic,
    this.github,
    this.cv,
    required this.languages,
  });

  final String username;
  final String? bio;
  final String? emailPublic;
  final String? github;
  final String? cv;
  final List<String> languages;

  factory SocialProfile.fromJson(Map<String, dynamic> json) {
    final languagesRaw = json['languages'];
    final languages = <String>[];
    if (languagesRaw is List) {
      for (final item in languagesRaw) {
        if (item is String && item.trim().isNotEmpty) {
          languages.add(item.trim());
        }
      }
    }

    return SocialProfile(
      username: json['username'] as String? ?? '',
      bio: json['bio'] as String?,
      emailPublic: json['email_public'] as String?,
      github: json['github'] as String?,
      cv: json['cv'] as String?,
      languages: languages,
    );
  }
}

class ProfileBundle {
  const ProfileBundle({
    required this.session,
    required this.settings,
    required this.deletion,
    required this.social,
  });

  final ProfileSession session;
  final ProfileSettings settings;
  final DeletionStatus deletion;
  final SocialProfile social;
}
