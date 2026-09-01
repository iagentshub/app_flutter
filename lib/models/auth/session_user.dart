class SessionUser {
  const SessionUser({
    this.id = '',
    required this.username,
    required this.role,
    this.email,
    this.displayName,
    this.avatarUrl,
    this.legalAcceptanceRequired = false,
  });

  final String id;
  final String username;
  final String role;
  final String? email;
  final String? displayName;

  /// Ruta relativa de la foto de perfil, o `null` si no hay. La publica
  /// `/api/auth/me` con la versión del contenido dentro.
  final String? avatarUrl;
  final bool legalAcceptanceRequired;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'guest',
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      legalAcceptanceRequired: json['legal_acceptance_required'] == true,
    );
  }

  /// Copia con otra foto. `dejarSinFoto` distingue «no lo cambies» de
  /// «ponlo a null», que con un parámetro opcional no se puede expresar.
  SessionUser conAvatar(String? url, {bool dejarSinFoto = false}) {
    return SessionUser(
      id: id,
      username: username,
      role: role,
      email: email,
      displayName: displayName,
      avatarUrl: dejarSinFoto ? null : (url ?? avatarUrl),
      legalAcceptanceRequired: legalAcceptanceRequired,
    );
  }

  SessionUser conAceptacionLegalRequerida(bool required) {
    return SessionUser(
      id: id,
      username: username,
      role: role,
      email: email,
      displayName: displayName,
      avatarUrl: avatarUrl,
      legalAcceptanceRequired: required,
    );
  }
}
