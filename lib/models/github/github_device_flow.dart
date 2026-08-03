// Modelos del GitHub OAuth Device Flow — compartidos entre "Conectar con
// GitHub" (vincular una cuenta proveedor en Connections, ver
// features/connections/repositories/accounts_repository.dart) y "Continuar
// con GitHub" (login de la app, ver
// features/auth/repositories/auth_repository.dart). Misma forma de
// respuesta en ambos casos — el backend comparte la lógica en
// app/auth/github_oauth.py.

/// Respuesta de `POST .../github/device-code`: código que el usuario debe
/// introducir en [verificationUri] para autorizar el acceso.
class GithubDeviceCode {
  const GithubDeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int expiresIn;
  final int interval;

  factory GithubDeviceCode.fromJson(Map<String, dynamic> json) {
    return GithubDeviceCode(
      deviceCode: json['device_code'] as String? ?? '',
      userCode: json['user_code'] as String? ?? '',
      verificationUri: json['verification_uri'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 900,
      interval: json['interval'] as int? ?? 5,
    );
  }
}

/// Resultado de sondear `POST .../github/device-token`.
class GithubDeviceTokenResult {
  const GithubDeviceTokenResult({
    required this.ok,
    required this.pending,
    this.slowDown = false,
    this.accessToken,
    this.error,
  });

  final bool ok;
  final bool pending;
  final bool slowDown;
  final String? accessToken;
  final String? error;

  factory GithubDeviceTokenResult.fromJson(Map<String, dynamic> json) {
    return GithubDeviceTokenResult(
      ok: json['ok'] == true,
      pending: json['pending'] == true,
      slowDown: json['slow_down'] == true,
      accessToken: json['access_token'] as String?,
      error: json['error'] as String?,
    );
  }
}
