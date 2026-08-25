class ProfileSession {
  const ProfileSession({
    this.id = '',
    required this.username,
    required this.role,
    this.groupId,
    this.groupName,
    this.authMethod,
    this.email,
    this.isEmailPublic = false,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String role;
  final String? groupId;
  final String? groupName;
  final String? authMethod;
  final String? email;
  final bool isEmailPublic;

  /// Ruta relativa de la foto, o `null` si no hay. Misma convención que el
  /// perfil público. Lleva dentro la versión del contenido, así que cambiar la
  /// foto cambia la URL y la caché deja de servir la anterior.
  final String? avatarUrl;

  factory ProfileSession.fromJson(Map<String, dynamic> json) {
    return ProfileSession(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'user',
      groupId: json['group_id'] as String?,
      groupName: json['group_name'] as String?,
      authMethod: json['auth_method'] as String?,
      email: json['email'] as String?,
      isEmailPublic: json['is_email_public'] == true,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}

class ProfileSettings {
  const ProfileSettings({
    required this.theme,
    required this.language,
    required this.themeConfigurable,
    required this.defaultTheme,
  });

  final String theme;
  final String language;
  final bool themeConfigurable;
  final String defaultTheme;

  factory ProfileSettings.fromJson(Map<String, dynamic> json) {
    return ProfileSettings(
      theme: json['theme'] as String? ?? 'dark-red',
      language: json['language'] as String? ?? 'es',
      themeConfigurable: json['theme_configurable'] != false,
      defaultTheme: json['default_theme'] as String? ?? 'dark-red',
    );
  }
}

class DeletionStatus {
  const DeletionStatus({required this.scheduled, this.deletionDate});

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
    this.avatarUrl,
    this.bio,
    this.emailPublic,
    this.github,
    this.cv,
    required this.languages,
    this.createdAt,
  });

  final String username;
  final String? avatarUrl;
  final String? bio;
  final String? emailPublic;
  final String? github;
  final String? cv;
  final List<String> languages;
  final String? createdAt;

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
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      emailPublic: json['email_public'] as String?,
      github: json['github'] as String?,
      cv: json['cv'] as String?,
      languages: languages,
      createdAt: (json['joined_at'] ?? json['created_at']) as String?,
    );
  }
}

class LicenseInfo {
  const LicenseInfo({required this.tier, this.status});

  final String tier;
  final String? status;

  factory LicenseInfo.fromJson(Map<String, dynamic> json) {
    return LicenseInfo(
      tier: json['tier'] as String? ?? 'free',
      status: json['status'] as String?,
    );
  }
}

class ProfileBundle {
  const ProfileBundle({
    required this.session,
    required this.settings,
    required this.deletion,
    required this.social,
    required this.license,
  });

  final ProfileSession session;
  final ProfileSettings settings;
  final DeletionStatus deletion;
  final SocialProfile social;
  final LicenseInfo license;
}

/// Una sesión abierta del usuario, tal y como la lista `GET /api/auth/sessions`.
///
/// La API no devuelve el refresh ni sus hashes: son credenciales vivas, no
/// datos que mostrar. Lo que llega es lo que permite reconocer un acceso
/// —cuándo empezó, desde dónde y con qué cliente— y decidir si cerrarlo.
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.current,
    this.createdAt,
    this.lastSeenAt,
    this.ip,
    this.userAgent,
  });

  final String id;
  final bool current;
  final String? createdAt;
  final String? lastSeenAt;
  final String? ip;
  final String? userAgent;

  factory ActiveSession.fromJson(Map<String, dynamic> json) {
    return ActiveSession(
      id: json['id'] as String? ?? '',
      current: json['current'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      lastSeenAt: json['last_seen_at'] as String?,
      ip: json['ip'] as String?,
      userAgent: json['user_agent'] as String?,
    );
  }
}
