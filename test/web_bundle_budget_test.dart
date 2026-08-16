import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El presupuesto de tamaño solo sirve si alguien lo ejecuta. `flutter test` no
/// puede medir el bundle —no hay build web durante los tests—, así que lo que
/// se comprueba aquí es que el guardarraíl sigue montado: el script existe, es
/// ejecutable, y CI lo llama después de construir la web.
void main() {
  final script = File('tool/check_web_bundle_size.sh');
  final workflow = File('.github/workflows/flutter-ci.yml');

  test('el script del presupuesto existe y declara un umbral', () {
    expect(script.existsSync(), isTrue, reason: 'Falta ${script.path}');

    final fuente = script.readAsStringSync();
    final umbral = RegExp(
      r'MAX_MAIN_BUNDLE_BYTES:-(\d+)',
    ).firstMatch(fuente)?.group(1);

    expect(
      umbral,
      isNotNull,
      reason: 'El script tiene que fijar un MAX_MAIN_BUNDLE_BYTES por defecto.',
    );
    // Un umbral desactivado de facto —puesto en un número enorme para acallar
    // un fallo— es peor que no tenerlo: nadie vuelve a mirarlo.
    expect(
      int.parse(umbral!),
      lessThan(8 * 1024 * 1024),
      reason:
          'Un presupuesto de más de 8 MiB no está frenando nada. Difiere el '
          'módulo que hizo crecer el bundle en vez de subir el umbral.',
    );
  });

  test('el script es ejecutable', () {
    // Sin el bit de ejecución, el paso de CI falla con «permission denied» y
    // el fallo parece del script, no del `git update-index` que faltó.
    expect(
      Process.runSync('test', ['-x', script.path]).exitCode,
      0,
      reason: 'chmod +x ${script.path}',
    );
  }, skip: Platform.isWindows);

  test('CI ejecuta el presupuesto después de construir la web', () {
    final lineas = workflow.readAsLinesSync();
    final build = lineas.indexWhere(
      (linea) => linea.contains('flutter build web --release'),
    );
    final presupuesto = lineas.indexWhere(
      (linea) => linea.contains('tool/check_web_bundle_size.sh'),
    );

    expect(build, isNonNegative, reason: 'CI ya no construye la web.');
    expect(
      presupuesto,
      isNonNegative,
      reason:
          'CI dejó de comprobar el presupuesto: el bundle puede volver a '
          'crecer sin que nadie lo vea.',
    );
    expect(
      presupuesto,
      greaterThan(build),
      reason: 'El presupuesto mide build/web: tiene que ir tras la build.',
    );
  });
}
