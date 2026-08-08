import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/local_store.dart';
import '../../core/storage/secure_store.dart';
import '../../models/auth/session_user.dart';

class SessionController extends ChangeNotifier {
  SessionController._(this._secureStore);

  static const _tokenKey = 'ga_token';
  static const _usernameKey = 'session_username';
  static const _roleKey = 'session_role';

  final SecureStore _secureStore;
  bool _isLoggedIn = false;
  String? _gaToken;
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
      // El rol persistido es solo una ayuda de arranque, no una fuente de
      // autorización: puede ser manipulado fuera de la app. Hasta que
      // /api/auth/me lo revalide, la sesión arranca con privilegios mínimos.
      controller._user = SessionUser(username: username, role: 'user');
      controller._isLoggedIn = true;

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
      } on Object {
        // La limpieza local debe continuar aunque el almacén nativo falle.
      }
    }
    return controller;
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get gaToken => _gaToken;
  SessionUser? get user => _user;

  /// [remember] controla si la sesión sobrevive a reiniciar la app. Si es
  /// false (invitado, o "recordar cuenta" desmarcado en login), la sesión
  /// vive solo en memoria durante esta ejecución y se limpia cualquier
  /// sesión persistida anteriormente para evitar reutilizarla por error.
  Future<void> login({
    required String token,
    required SessionUser user,
    bool remember = true,
  }) async {
    _gaToken = token;
    _user = user;
    _isLoggedIn = true;

    final prefs = await LocalStore.instance();
    if (remember) {
      try {
        await _secureStore.write(_tokenKey, token);
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
    if (!_isLoggedIn) return;
    _isLoggedIn = false;
    _gaToken = null;
    _user = null;

    final prefs = await LocalStore.instance();
    await _deleteSecureToken();
    await _clearPersistedMetadata(prefs);

    notifyListeners();
  }

  Future<void> _deleteSecureToken() async {
    try {
      await _secureStore.delete(_tokenKey);
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
