class AuthResult {
  const AuthResult({
    required this.ok,
    this.username,
  });

  final bool ok;
  final String? username;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      ok: json['ok'] == true,
      username: json['username'] as String?,
    );
  }
}
