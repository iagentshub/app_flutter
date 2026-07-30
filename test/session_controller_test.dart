import 'package:app_flutter/core/storage/secure_store.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'migra el token legado y arranca siempre con privilegios mínimos',
    () async {
      SharedPreferences.setMockInitialValues({
        'ga_token': 'token',
        'session_username': 'alice',
        'session_role': 'admin',
      });
      final secrets = MemorySecureStore();

      final controller = await SessionController.bootstrap(
        secureStore: secrets,
      );
      final prefs = await SharedPreferences.getInstance();

      expect(controller.isLoggedIn, isTrue);
      expect(controller.gaToken, 'token');
      expect(controller.user?.username, 'alice');
      expect(controller.user?.role, 'user');
      expect(secrets.values['ga_token'], 'token');
      expect(prefs.getString('ga_token'), isNull);
    },
  );

  test('elimina credenciales persistidas incompletas', () async {
    SharedPreferences.setMockInitialValues({
      'ga_token': 'stale-token',
      'session_username': 'alice',
    });
    final secrets = MemorySecureStore();

    final controller = await SessionController.bootstrap(secureStore: secrets);
    final prefs = await SharedPreferences.getInstance();

    expect(controller.isLoggedIn, isFalse);
    expect(prefs.getString('ga_token'), isNull);
    expect(prefs.getString('session_username'), isNull);
    expect(prefs.getString('session_role'), isNull);
  });

  test('una sesión no recordada permanece solo en memoria', () async {
    SharedPreferences.setMockInitialValues({
      'ga_token': 'old-token',
      'session_username': 'old-user',
      'session_role': 'user',
    });
    final secrets = MemorySecureStore();
    final controller = await SessionController.bootstrap(secureStore: secrets);

    await controller.login(
      token: 'guest-token',
      user: const SessionUser(username: 'guest', role: 'guest'),
      remember: false,
    );
    final prefs = await SharedPreferences.getInstance();

    expect(controller.isLoggedIn, isTrue);
    expect(controller.gaToken, 'guest-token');
    expect(prefs.getString('ga_token'), isNull);
    expect(prefs.getString('session_username'), isNull);
    expect(prefs.getString('session_role'), isNull);
    expect(secrets.values['ga_token'], isNull);
  });

  test(
    'una sesión recordada persiste el token solo en almacenamiento seguro',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = MemorySecureStore();
      final controller = await SessionController.bootstrap(
        secureStore: secrets,
      );

      await controller.login(
        token: 'new-token',
        user: const SessionUser(username: 'alice', role: 'admin'),
      );
      final prefs = await SharedPreferences.getInstance();

      expect(secrets.values['ga_token'], 'new-token');
      expect(prefs.getString('ga_token'), isNull);
      expect(prefs.getString('session_username'), 'alice');
      expect(prefs.getString('session_role'), 'admin');

      await controller.logout();

      expect(secrets.values['ga_token'], isNull);
      expect(prefs.getString('session_username'), isNull);
      expect(controller.isLoggedIn, isFalse);
    },
  );

  test(
    'un fallo de lectura segura no destruye una sesión persistida',
    () async {
      SharedPreferences.setMockInitialValues({
        'session_username': 'alice',
        'session_role': 'admin',
      });
      final controller = await SessionController.bootstrap(
        secureStore: ThrowingReadSecureStore(),
      );
      final prefs = await SharedPreferences.getInstance();

      expect(controller.isLoggedIn, isFalse);
      expect(prefs.getString('session_username'), 'alice');
      expect(prefs.getString('session_role'), 'admin');
    },
  );
}

class MemorySecureStore implements SecureStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class ThrowingReadSecureStore extends MemorySecureStore {
  @override
  Future<String?> read(String key) => Future.error(StateError('unavailable'));
}
