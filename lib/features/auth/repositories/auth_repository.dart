import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/csrf_token.dart';
import '../../../models/auth/auth_result.dart';
import '../../../models/auth/session_user.dart';
import '../../../models/github/github_device_flow.dart';

/// Resultado de sondear el login con GitHub: si [isReady] es true, [gaToken]
/// y [authResult] ya están listos para pasar a `SessionController.login`
/// (igual que tras `AuthRepository.login`); si no, mira [tokenResult] para
/// saber si sigue pendiente o hubo un error.
class GithubLoginPollResult {
  const GithubLoginPollResult({
    required this.tokenResult,
    this.authResult,
    this.gaToken,
  });

  final GithubDeviceTokenResult tokenResult;
  final AuthResult? authResult;
  final String? gaToken;

  bool get isReady =>
      authResult != null && gaToken != null && gaToken!.isNotEmpty;
}

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<(AuthResult, String)> login({
    required String identifier,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/login',
      body: {'identifier': identifier.trim(), 'password': password},
    );

    final token = _apiClient.extractGaToken(response.headers);
    if (token == null || token.isEmpty) {
      throw ApiError(
        statusCode: 500,
        message: 'El backend no devolvio cookie de sesion ga_token',
      );
    }

    final result = AuthResult.fromJson(response.json);
    return (result, token);
  }

  Future<(AuthResult, String)> guestLogin() async {
    final response = await _apiClient.post('/api/auth/guest');
    final token = _apiClient.extractGaToken(response.headers);
    if (token == null || token.isEmpty) {
      throw ApiError(
        statusCode: 500,
        message: 'El backend no devolvio cookie de sesion ga_token',
      );
    }

    final result = AuthResult.fromJson(response.json);
    return (result, token);
  }

  /// Inicia el login con GitHub (OAuth Device Flow) — sin sesión previa.
  Future<GithubDeviceCode> startGithubLogin() async {
    final response = await _apiClient.post('/api/auth/github/device-code');
    return GithubDeviceCode.fromJson(response.json);
  }

  /// Sondea si el usuario ya autorizó el login iniciado con
  /// [startGithubLogin]. Sigue el mismo patrón que [login]: el token real
  /// llega en la cookie `Set-Cookie`, no en el JSON.
  Future<GithubLoginPollResult> pollGithubLogin(String deviceCode) async {
    final response = await _apiClient.post(
      '/api/auth/github/device-token',
      body: {'device_code': deviceCode},
    );
    final tokenResult = GithubDeviceTokenResult.fromJson(response.json);
    if (!tokenResult.ok) {
      return GithubLoginPollResult(tokenResult: tokenResult);
    }
    final gaToken = _apiClient.extractGaToken(response.headers);
    if (gaToken == null || gaToken.isEmpty) {
      throw ApiError(
        statusCode: 500,
        message: 'El backend no devolvio cookie de sesion ga_token',
      );
    }
    return GithubLoginPollResult(
      tokenResult: tokenResult,
      authResult: AuthResult.fromJson(response.json),
      gaToken: gaToken,
    );
  }

  Future<SessionUser> me(String gaToken, {Duration? timeout}) async {
    final response = await _apiClient.get(
      '/api/auth/me',
      gaToken: gaToken,
      timeout: timeout,
    );
    return SessionUser.fromJson(response.json);
  }

  Future<void> logout(String gaToken) async {
    try {
      await _apiClient.post('/api/auth/logout', gaToken: gaToken);
    } catch (_) {
      // Aunque el backend falle en logout, limpiamos sesión local igualmente.
    }
    // El token anti-CSRF acompaña a la sesión: si sobrevive, la siguiente
    // cuenta que entre en este dispositivo arrastra el de la anterior y sus
    // mutaciones salen con un token que ya no cuadra.
    forgetCsrfToken();
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/register',
      body: {
        'username': username.trim().toLowerCase(),
        'email': email.trim().toLowerCase(),
        'password': password,
      },
    );
    return response.json['ok'] == true;
  }

  Future<bool> forgotPassword({required String email}) async {
    final response = await _apiClient.post(
      '/api/auth/forgot-password',
      body: {'email': email.trim()},
    );
    return response.json['ok'] == true;
  }

  Future<bool> resetPassword({
    required String token,
    required String password,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/reset-password',
      body: {'token': token.trim(), 'password': password},
    );
    return response.json['ok'] == true;
  }

  Future<(bool, String?)> verifyEmail(String token) async {
    final response = await _apiClient.get(
      '/api/auth/verify?token=${Uri.encodeQueryComponent(token)}',
    );
    final ok = response.json['ok'] == true;
    return (ok, _apiClient.extractGaToken(response.headers));
  }

  Future<Map<String, dynamic>> platformPublic() async {
    final response = await _apiClient.get('/api/settings/platform/public');
    return response.json;
  }

  Future<String> authorizeVsCode(
    String gaToken, {
    required String state,
  }) async {
    final response = await _apiClient.post(
      '/api/auth/vscode/authorize',
      gaToken: gaToken,
      body: {'state': state},
    );
    return response.json['code'] as String? ?? '';
  }

  /// Idioma guardado en las preferencias del usuario ('es'/'en'), o null si
  /// no se pudo obtener (sesión inválida, backend caído, etc.).
  Future<String?> getLanguage(String gaToken) async {
    try {
      return (await getSettings(gaToken))['language'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> getSettings(String gaToken) async {
    final response = await _apiClient.get('/api/settings', gaToken: gaToken);
    return response.json;
  }

  /// Limpia la caché de peticiones (ver ApiClient) — se llama tras iniciar
  /// sesión por si se cambió de cuenta sin reiniciar la app.
  void clearCache() => _apiClient.invalidateCache();
}
