import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

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

      expect(controller.status, SessionStatus.restoring);
      expect(controller.isLoggedIn, isFalse);
      expect(controller.gaToken, 'token');
      expect(controller.user?.username, 'alice');
      expect(controller.user?.role, 'user');
      expect(secrets.values['ga_token'], 'token');
      expect(prefs.getString('ga_token'), isNull);
    },
  );

  test('solo considera autenticada una sesión después de validarla', () async {
    SharedPreferences.setMockInitialValues({
      'session_username': 'alice',
      'session_role': 'admin',
    });
    final secrets = MemorySecureStore()..values['ga_token'] = 'token';
    final controller = await SessionController.bootstrap(secureStore: secrets);

    expect(controller.status, SessionStatus.restoring);
    expect(controller.hasRestorableSession, isTrue);

    controller.markBackendUnavailable();
    expect(controller.status, SessionStatus.backendUnavailable);
    expect(controller.gaToken, 'token');
    expect(secrets.values['ga_token'], 'token');

    controller.beginRevalidation();
    expect(controller.status, SessionStatus.restoring);

    await controller.login(
      token: 'token',
      user: const SessionUser(username: 'alice', role: 'admin'),
    );
    expect(controller.status, SessionStatus.authenticated);
    expect(controller.isLoggedIn, isTrue);
  });

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
    'logout() es idempotente: una segunda llamada no reemite notificaciones',
    () async {
      SharedPreferences.setMockInitialValues({});
      final secrets = MemorySecureStore();
      final controller = await SessionController.bootstrap(
        secureStore: secrets,
      );
      await controller.login(
        token: 'token',
        user: const SessionUser(username: 'alice', role: 'admin'),
      );

      var notifications = 0;
      controller.addListener(() => notifications += 1);

      // Simula varias peticiones en vuelo recibiendo 401 casi a la vez.
      await Future.wait([controller.logout(), controller.logout()]);

      expect(controller.isLoggedIn, isFalse);
      expect(notifications, 1);
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

  /// La identidad de caché tiene que cambiar con la cuenta y con cada login,
  /// también en web, donde el token que ve la app es una constante igual para
  /// todos los usuarios.
  test('cacheIdentity distingue cuentas y sesiones sucesivas', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );

    final anonima = controller.cacheIdentity;
    expect(anonima, startsWith('anon'));

    await controller.login(
      token: 'token',
      user: const SessionUser(username: 'ana', role: 'user'),
    );
    final deAna = controller.cacheIdentity;
    expect(deAna, isNot(anonima));
    expect(deAna, contains('ana'));

    await controller.logout();
    await controller.login(
      token: 'token',
      user: const SessionUser(username: 'bruno', role: 'user'),
    );
    final deBruno = controller.cacheIdentity;
    expect(deBruno, isNot(deAna));
    expect(deBruno, contains('bruno'));

    // Y volver a entrar con la misma cuenta tampoco reutiliza la identidad
    // anterior: cada sesión es una generación nueva.
    await controller.logout();
    await controller.login(
      token: 'token',
      user: const SessionUser(username: 'ana', role: 'user'),
    );
    expect(controller.cacheIdentity, isNot(deAna));
  });

  // ── Refresh token (punto 06: sesiones revocables) ─────────────────────────
  // Fuera de web las cookies las guarda la app. Sin persistir el refresh, una
  // sesión restaurada duraría lo que el access que se guardó con ella —30
  // minutos— por muy larga que sea la sesión real en el backend.

  test('el refresh se persiste solo cuando la sesión se recuerda', () async {
    SharedPreferences.setMockInitialValues({});
    final secrets = MemorySecureStore();
    final controller = await SessionController.bootstrap(secureStore: secrets);

    // Llega con el Set-Cookie del login, antes de que haya sesión.
    await controller.rememberRefreshToken('iar_uno');
    expect(controller.refreshToken, 'iar_uno');
    expect(secrets.values['ga_refresh'], isNull);

    await controller.login(
      token: 'token',
      user: const SessionUser(username: 'alice', role: 'user'),
    );
    expect(secrets.values['ga_refresh'], 'iar_uno');
  });

  test('una sesión que no se recuerda no deja el refresh en disco', () async {
    SharedPreferences.setMockInitialValues({});
    final secrets = MemorySecureStore();
    final controller = await SessionController.bootstrap(secureStore: secrets);

    await controller.rememberRefreshToken('iar_invitado');
    await controller.login(
      token: 'token',
      user: const SessionUser(username: 'guest', role: 'guest'),
      remember: false,
    );

    expect(controller.refreshToken, 'iar_invitado', reason: 'vale en memoria');
    expect(secrets.values['ga_refresh'], isNull);
  });

  test('renovar no cambia la identidad de caché ni el estado', () async {
    SharedPreferences.setMockInitialValues({});
    final secrets = MemorySecureStore();
    final controller = await SessionController.bootstrap(secureStore: secrets);
    await controller.login(
      token: 'viejo',
      user: const SessionUser(username: 'alice', role: 'user'),
    );
    final identidad = controller.cacheIdentity;

    await controller.renewAccessToken('nuevo');

    expect(controller.gaToken, 'nuevo');
    expect(secrets.values['ga_token'], 'nuevo');
    expect(controller.status, SessionStatus.authenticated);
    expect(
      controller.cacheIdentity,
      identidad,
      reason: 'renovar no es entrar: invalidaría toda la caché cada 30 min',
    );
  });

  test('cerrar sesión borra también el refresh', () async {
    SharedPreferences.setMockInitialValues({});
    final secrets = MemorySecureStore();
    final controller = await SessionController.bootstrap(secureStore: secrets);
    await controller.rememberRefreshToken('iar_uno');
    await controller.login(
      token: 'token',
      user: const SessionUser(username: 'alice', role: 'user'),
    );

    await controller.logout();

    expect(controller.refreshToken, isNull);
    expect(secrets.values['ga_refresh'], isNull);
  });
}
