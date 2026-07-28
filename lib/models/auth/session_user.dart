class SessionUser {
  const SessionUser({
    required this.username,
    required this.role,
    this.email,
    this.displayName,
  });

  final String username;
  final String role;
  final String? email;
  final String? displayName;

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      username: json['username'] as String? ?? '',
      role: json['role'] as String? ?? 'guest',
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
    );
  }
}
