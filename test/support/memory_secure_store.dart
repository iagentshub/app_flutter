import 'package:app_flutter/core/storage/secure_store.dart';

/// [SecureStore] en memoria para los tests que necesitan una sesión.
///
/// Antes se copiaba en cada archivo que arrancaba un `SessionController`
/// (cinco copias idénticas); vive aquí para tener una sola definición.
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

/// Almacén cuyo `read` siempre falla, para comprobar que un fallo del
/// almacén seguro no impide arrancar la app.
class ThrowingReadSecureStore extends MemorySecureStore {
  @override
  Future<String?> read(String key) => Future.error(StateError('unavailable'));
}
