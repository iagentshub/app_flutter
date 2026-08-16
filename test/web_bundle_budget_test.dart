import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El presupuesto de tamaño solo sirve si alguien lo ejecuta. `flutter test` no
/// puede medir el bundle —no hay build web durante los tests—, así que lo que
/// se comprueba aquí es que el guardarraíl sigue montado: el script existe, es
/// ejecutable, y CI lo llama después de construir la web.
void main() {
  final script = File('tool/check_web_bundle_size.sh');
  final build = File('tool/build_web.sh');
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

  test('los scripts son ejecutables', () {
    // Sin el bit de ejecución, el paso de CI falla con «permission denied» y
    // el fallo parece del script, no del `git update-index` que faltó.
    for (final fichero in [script, build]) {
      expect(
        Process.runSync('test', ['-x', fichero.path]).exitCode,
        0,
        reason: 'chmod +x ${fichero.path}',
      );
    }
  }, skip: Platform.isWindows);

  // El comando de compilación vive en tool/build_web.sh y no suelto en cada
  // workflow porque sus flags tienen la otra mitad en la CSP de nginx, y se
  // invoca desde cuatro repositorios. Si alguien lo devuelve a un `flutter
  // build web` a pelo aquí, ese acoplamiento vuelve a quedar sin dueño.
  test('CI construye la web con tool/build_web.sh', () {
    final fuente = workflow.readAsStringSync();

    expect(
      build.existsSync(),
      isTrue,
      reason: 'Falta ${build.path}, que es el único canal de compilación.',
    );
    expect(
      fuente,
      isNot(contains('flutter build web')),
      reason:
          'Un `flutter build web` suelto en el workflow se salta los flags de '
          'tool/build_web.sh y produce una web que la CSP de nginx bloquea.',
    );
  });

  test('CI ejecuta el presupuesto después de construir la web', () {
    final lineas = workflow.readAsLinesSync();
    final compilacion = lineas.indexWhere(
      (linea) => linea.contains('tool/build_web.sh'),
    );
    final presupuesto = lineas.indexWhere(
      (linea) => linea.contains('tool/check_web_bundle_size.sh'),
    );

    expect(compilacion, isNonNegative, reason: 'CI ya no construye la web.');
    expect(
      presupuesto,
      isNonNegative,
      reason:
          'CI dejó de comprobar el presupuesto: el bundle puede volver a '
          'crecer sin que nadie lo vea.',
    );
    expect(
      presupuesto,
      greaterThan(compilacion),
      reason: 'El presupuesto mide build/web: tiene que ir tras la build.',
    );
  });
}
