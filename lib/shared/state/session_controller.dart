import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/local_store.dart';
import '../../core/storage/secure_store.dart';
import '../../models/auth/session_user.dart';

enum SessionStatus { signedOut, restoring, authenticated, backendUnavailable }

class SessionController extends ChangeNotifier {
  SessionController._(this._secureStore);

  static const _tokenKey = 'ga_token';
  static const _refreshKey = 'ga_refresh';
  static const _usernameKey = 'session_username';
  static const _roleKey = 'session_role';

  final SecureStore _secureStore;
  SessionStatus _status = SessionStatus.signedOut;
  String? _gaToken;
  String? _refreshToken;
  SessionUser? _user;

  static Future<SessionController> bootstrap({
    SecureStore secureStore = const PlatformSecureStore(),
  }) async {
    final controller = SessionController._(secureStore);
    final prefs = await LocalStore.instance();

    String? secureToken;
    var secureReadSucceeded = true;
    try {
      secureToken = await secureStore.read(_tokenKey);
    } on Object {
      secureReadSucceeded = false;
      // Un fallo puntual del almacén seguro no debe impedir abrir la app.
    }

    final legacyToken = prefs.getString(_tokenKey);
    final token = secureToken?.isNotEmpty == true ? secureToken : legacyToken;
    final username = prefs.getString(_usernameKey);
    final role = prefs.getString(_roleKey);

    if (token != null && token.isNotEmpty && username != null && role != null) {
      controller._gaToken = token;
      // Fuera de web las cookies las guarda la app, no el navegador: sin el
      // refresh persistido, una sesión restaurada duraría lo que el access que
      // se guardó con ella —30 minutos— por muy larga que sea la sesión real.
      try {
        controller._refreshToken = await secureStore.read(_refreshKey);
      } on Object {
        // Sin refresh la sesión sigue siendo usable hasta que caduque el access.
      }
      // El rol persistido es solo una ayuda de arranque, no una fuente de
      // autorización: puede ser manipulado fuera de la app. Hasta que
      // /api/auth/me lo revalide, la sesión arranca con privilegios mínimos.
      controller._user = SessionUser(username: username, role: 'user');
      controller._status = SessionStatus.restoring;

      if (legacyToken != null) {
        if (secureToken?.isNotEmpty == true) {
          await prefs.remove(_tokenKey);
        } else {
          try {
            await secureStore.write(_tokenKey, legacyToken);
            await prefs.remove(_tokenKey);
          } on Object {
            // Se conserva el valor legado hasta poder migrarlo sin perder sesión.
          }
        }
      }
    } else if (legacyToken != null ||
        (secureReadSucceeded &&
            (secureToken != null || username != null || role != null))) {
      // Una escritura interrumpida no debe dejar credenciales parciales.
      await prefs.remove(_tokenKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_roleKey);
      try {
        await secureStore.delete(_tokenKey);
        await secureStore.delete(_refreshKey);
      } on Object {
        // La limpieza local debe continuar aunque el almacén nativo falle.
      }
    }
    return controller;
  }

  SessionStatus get status => _status;
  bool get isLoggedIn => _status == SessionStatus.authenticated;
  bool get hasRestorableSession =>
      _gaToken != null && _gaToken!.isNotEmpty && _user != null;
  String? get gaToken => _gaToken;

  /// El `ga_refresh` guardado. Solo se usa fuera de web: en el navegador la
  /// cookie es HttpOnly y viaja sola.
  String? get refreshToken => _refreshToken;
  SessionUser? get user => _user;

  /// Recuerda el `ga_refresh` que llegó en un `Set-Cookie`, venga del login o
  /// de una renovación.
  ///
  /// Se guarda en memoria siempre y en el almacén seguro solo si ya hay una
  /// sesión persistida: durante el login todavía no la hay, y de persistirlo
  /// aquí se colaría la credencial de una sesión que el usuario pidió no
  /// recordar. Ese caso lo resuelve `login()`, que escribe lo que haya en
  /// memoria justo cuando ya sabe si hay que recordarla.
  Future<void> rememberRefreshToken(String token) async {
    if (token.isEmpty || token == _refreshToken) return;
    _refreshToken = token;
    if (!hasRestorableSession) return;
    try {
      await _secureStore.write(_refreshKey, token);
    } on Object {
      // Sesión renovada en memoria; sin persistir solo se pierde al reiniciar.
    }
  }

  /// Sustituye el access token tras una renovación, sin tocar el estado de la
  /// sesión: renovar no es entrar, y `login()` incrementa la época, lo que
  /// invalidaría toda la caché de la app en cada renovación.
  Future<void> renewAccessToken(String token) async {
    if (!hasRestorableSession || token.isEmpty) return;
    _gaToken = token;
    try {
      await _secureStore.write(_tokenKey, token);
    } on Object {
      // Igual que arriba: en memoria ya está renovado.
    }
  }

  /// Cambia con cada login y cada logout, además de con la cuenta.
  int _epoch = 0;

  /// Identidad de la sesión activa, para claves de caché.
  ///
  /// No sirve el token: en web `extractGaToken` devuelve siempre la misma
  /// constante porque la cookie real es HttpOnly y la app no la ve, así que
  /// una clave construida con él vale lo mismo para todas las cuentas. Este
  /// valor sí cambia al cambiar de usuario, también en web.
  String get cacheIdentity => hasRestorableSession
      ? '${_user?.username ?? ''}#$_epoch'
      : 'anon#$_epoch';

  /// Vuelve a proteger las rutas internas mientras se comprueba la sesión
  /// persistida. El token se conserva para poder reintentar después de un
  /// fallo de red sin obligar al usuario a autenticarse de nuevo.
  void beginRevalidation() {
    if (!hasRestorableSession || _status == SessionStatus.restoring) return;
    _status = SessionStatus.restoring;
    notifyListeners();
  }

  /// La identidad sigue almacenada, pero no se considera autenticada mientras
  /// el backend no pueda confirmar `/api/auth/me`.
  void markBackendUnavailable() {
    if (!hasRestorableSession || _status == SessionStatus.backendUnavailable) {
      return;
    }
    _status = SessionStatus.backendUnavailable;
    notifyListeners();
  }

  /// [remember] controla si la sesión sobrevive a reiniciar la app. Si es
  /// false (invitado, o "recordar cuenta" desmarcado en login), la sesión
  /// vive solo en memoria durante esta ejecución y se limpia cualquier
  /// sesión persistida anteriormente para evitar reutilizarla por error.
  /// Cambia solo la foto del usuario en sesión.
  ///
  /// El menú lateral pinta el avatar en todas las pantallas, y la sesión se
  /// carga al entrar: sin esto, cambiar la foto en Perfil dejaba el sidebar con
  /// la anterior hasta el siguiente arranque. No toca `_epoch` —cambiar de foto
  /// no es entrar— ni persiste nada: el valor vuelve de `/api/auth/me`.
  void actualizarAvatar(String? url) {
    final actual = _user;
    if (actual == null || actual.avatarUrl == url) return;
    _user = actual.conAvatar(url, dejarSinFoto: url == null);
    notifyListeners();
  }

  Future<void> login({
    required String token,
    required SessionUser user,
    bool remember = true,
  }) async {
    _gaToken = token;
    _user = user;
    _status = SessionStatus.authenticated;
    _epoch += 1;

    final prefs = await LocalStore.instance();
    if (remember) {
      try {
        await _secureStore.write(_tokenKey, token);
        // `_refreshToken` ya lo puso `rememberRefreshToken` con el Set-Cookie
        // de esta misma respuesta de login.
        final refresh = _refreshToken;
        if (refresh != null) await _secureStore.write(_refreshKey, refresh);
        await prefs.remove(_tokenKey);
        await prefs.setString(_usernameKey, user.username);
        await prefs.setString(_roleKey, user.role);
      } on Object {
        // Mantener la sesión actual en memoria es más seguro que degradar el
        // token a almacenamiento sin cifrar.
        await _clearPersistedMetadata(prefs);
      }
    } else {
      await _deleteSecureToken();
      await _clearPersistedMetadata(prefs);
    }

    notifyListeners();
  }

  Future<void> logout() async {
    // Evita trabajo y notificaciones redundantes cuando varias peticiones
    // en vuelo reciben un 401 casi a la vez (p. ej. una vista que dispara
    // varias llamadas en paralelo justo cuando el token caduca).
    if (_status == SessionStatus.signedOut && !hasRestorableSession) return;
    _status = SessionStatus.signedOut;
    _gaToken = null;
    _refreshToken = null;
    _user = null;
    _epoch += 1;

    final prefs = await LocalStore.instance();
    await _deleteSecureToken();
    await _clearPersistedMetadata(prefs);

    notifyListeners();
  }

  Future<void> _deleteSecureToken() async {
    try {
      await _secureStore.delete(_tokenKey);
      await _secureStore.delete(_refreshKey);
    } on Object {
      // El estado en memoria y el almacenamiento local sí deben limpiarse.
    }
  }

  static Future<void> _clearPersistedMetadata(SharedPreferences prefs) async {
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);
  }
}
