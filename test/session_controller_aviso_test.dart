import 'dart:async';

import 'package:app_flutter/core/storage/secure_store.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

/// Almacén cuya escritura **nunca contesta**, ni bien ni mal.
///
/// Es el caso que no cubría ningún otro doble: `ThrowingReadSecureStore` falla,
/// y un fallo se captura. Un `Future` que se queda pendiente no se captura —se
/// espera para siempre—, y eso es lo que hacía el Keychain de macOS con su
/// diálogo de autorización sin responder, o el navegador con el almacenamiento
/// bloqueado por la extensión de turno.
class _AlmacenQueNoContesta implements SecureStore {
  final _nunca = Completer<void>();

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) => _nunca.future;

  @override
  Future<void> delete(String key) => _nunca.future;
}

const _usuario = SessionUser(id: 'u1', username: 'ada', role: 'user');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('login avisa antes de persistir, no después', () async {
    final controller = await SessionController.bootstrap(
      secureStore: _AlmacenQueNoContesta(),
    );
    addTearDown(controller.dispose);

    var avisos = 0;
    controller.addListener(() => avisos += 1);

    // Sin `await` a propósito: la persistencia se queda pendiente para
    // siempre y el aviso tiene que haber salido igualmente. Antes iba después
    // de escribir, así que aquí no llegaba nunca y el router se quedaba
    // creyendo que nadie había entrado.
    unawaited(controller.login(token: 't', user: _usuario));

    expect(controller.isLoggedIn, isTrue);
    expect(
      avisos,
      1,
      reason: 'el router tiene que enterarse aunque el almacén no conteste',
    );
  });

  test('logout avisa antes de borrar, no después', () async {
    final lento = await SessionController.bootstrap(
      secureStore: _AlmacenQueNoContesta(),
    );
    addTearDown(lento.dispose);
    // Sin `await`: este almacén tampoco contesta al escribir, y lo que se
    // monta aquí es solo la sesión de partida.
    unawaited(lento.login(token: 't', user: _usuario));

    var avisos = 0;
    lento.addListener(() => avisos += 1);
    unawaited(lento.logout());

    expect(lento.isLoggedIn, isFalse);
    expect(
      avisos,
      1,
      reason: 'una sesión cerrada en memoria no puede quedar sin avisar',
    );
  });

  test('un almacén que falla no impide abrir la sesión', () async {
    final controller = await SessionController.bootstrap(
      secureStore: ThrowingReadSecureStore(),
    );
    addTearDown(controller.dispose);

    await controller.login(token: 't', user: _usuario);

    expect(controller.isLoggedIn, isTrue);
    expect(controller.gaToken, 't');
  });
}
