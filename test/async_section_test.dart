import 'package:app_flutter/core/network/api_error.dart';
import 'package:app_flutter/shared/state/async_section.dart';
import 'package:flutter_test/flutter_test.dart';

/// Veinte páginas repetían el mismo ciclo cargando / error / datos, y las
/// diferencias entre copias eran accidentales: unas conservaban los datos
/// viejos al fallar una recarga y otras los borraban, dejando la vista vacía
/// por un error de red. Aquí esa política se fija una sola vez.
void main() {
  test('publica los datos y deja de cargar', () async {
    final section = AsyncSection<List<String>>(
      fetch: () async => ['a', 'b'],
      genericError: () => 'error genérico',
    );
    addTearDown(section.dispose);

    expect(section.loading, isTrue, reason: 'arranca cargando');
    expect(section.hasData, isFalse);

    await section.load();

    expect(section.data, ['a', 'b']);
    expect(section.loading, isFalse);
    expect(section.error, isNull);
  });

  test('un ApiError se muestra con el mensaje del backend', () async {
    final section = AsyncSection<List<String>>(
      fetch: () async =>
          throw ApiError(statusCode: 403, message: 'Sin permiso'),
      genericError: () => 'error genérico',
    );
    addTearDown(section.dispose);

    await section.load();

    expect(section.error, 'Sin permiso');
    expect(section.loading, isFalse);
  });

  test('un fallo sin ApiError cae al mensaje traducido', () async {
    final section = AsyncSection<List<String>>(
      fetch: () async => throw StateError('sin red'),
      genericError: () => 'No se pudo cargar',
    );
    addTearDown(section.dispose);

    await section.load();

    expect(section.error, 'No se pudo cargar');
  });

  test('una recarga fallida conserva los datos anteriores', () async {
    var falla = false;
    final section = AsyncSection<List<String>>(
      fetch: () async {
        if (falla) throw ApiError(statusCode: 500, message: 'Se cayó');
        return ['a'];
      },
      genericError: () => 'error genérico',
    );
    addTearDown(section.dispose);

    await section.load();
    expect(section.data, ['a']);

    falla = true;
    await section.load();

    // Ésta es la decisión que cada página tomaba a su manera: vaciar la vista
    // por un error de red es peor que enseñar lo último bueno que se tenía.
    expect(section.data, ['a']);
    expect(section.error, 'Se cayó');
  });

  test('avisa al empezar y al terminar cada carga', () async {
    final section = AsyncSection<int>(
      fetch: () async => 1,
      genericError: () => 'error genérico',
    );
    addTearDown(section.dispose);
    var avisos = 0;
    section.addListener(() => avisos += 1);

    await section.load();

    expect(avisos, 2, reason: 'uno al entrar en carga y otro al resolverse');
  });

  test('no notifica después de dispose', () async {
    final section = AsyncSection<int>(
      fetch: () async => 1,
      genericError: () => 'error genérico',
    );
    var avisos = 0;
    section.addListener(() => avisos += 1);

    final carga = section.load();
    section.dispose();
    await carga;

    expect(avisos, lessThanOrEqualTo(1));
  });
}
