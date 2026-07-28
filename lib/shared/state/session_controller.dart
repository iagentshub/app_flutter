import 'package:flutter/foundation.dart';

import '../../core/storage/local_store.dart';
import '../../models/auth/session_user.dart';

class SessionController extends ChangeNotifier {
  SessionController._();

  static const _tokenKey = 'ga_token';
  static const _usernameKey = 'session_username';
  static const _roleKey = 'session_role';

  bool _isLoggedIn = false;
  String? _gaToken;
  SessionUser? _user;

  static Future<SessionController> bootstrap() async {
    final controller = SessionController._();
    final prefs = await LocalStore.instance();

    final token = prefs.getString(_tokenKey);
    final username = prefs.getString(_usernameKey);
    final role = prefs.getString(_roleKey);

    if (token != null && token.isNotEmpty && username != null && role != null) {
      controller._gaToken = token;
      controller._user = SessionUser(username: username, role: role);
      controller._isLoggedIn = true;
    }
    return controller;
  }

  bool get isLoggedIn => _isLoggedIn;
  String? get gaToken => _gaToken;
  SessionUser? get user => _user;

  Future<void> login({
    required String token,
    required SessionUser user,
  }) async {
    _gaToken = token;
    _user = user;
    _isLoggedIn = true;

    final prefs = await LocalStore.instance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_usernameKey, user.username);
    await prefs.setString(_roleKey, user.role);

    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _gaToken = null;
    _user = null;

    final prefs = await LocalStore.instance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_roleKey);

    notifyListeners();
  }
}
