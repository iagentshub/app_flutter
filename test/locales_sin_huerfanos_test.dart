import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `assets/locales/` llegó a tener 25 ficheros por idioma y la app solo cargaba
/// cinco. Los otros veinte —284 KB entre los dos idiomas— iban al bundle sin
/// que nadie los pidiera: eran el esquema anterior (un fichero por página,
/// consolidado después en `resources.json`) más los del sitio público, que
/// sirve React con sus propios locales.
///
/// El coste no es solo el peso: quien añadía una clave tenía que adivinar en
/// cuál de los dos ficheros con el mismo nombre debía tocar, y la mitad de las
/// veces escribía en el que no se lee.
void main() {
  test('cada fichero de locales corresponde a un namespace que se carga', () {
    // Los namespaces salen del código: `TranslatedTexts(namespace: 'x')` y
    // `LocaleLoader.load(namespace: 'x')`. Se leen aquí en vez de mantener una
    // lista a mano, que es lo que se desincroniza.
    final usados = <String>{};
    final declara = RegExp(r"namespace:\s*'([a-z_]+)'");
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      for (final m in declara.allMatches(f.readAsStringSync())) {
        usados.add(m.group(1)!);
      }
    }
    expect(usados, isNotEmpty, reason: 'no se detectó ningún namespace');

    for (final idioma in const ['es', 'en']) {
      final huerfanos =
          Directory('assets/locales/$idioma')
              .listSync()
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last.replaceAll('.json', ''))
              .where((n) => !usados.contains(n))
              .toList()
            ..sort();

      expect(
        huerfanos,
        isEmpty,
        reason:
            'assets/locales/$idioma tiene ficheros que no carga nadie.\n'
            'Bórralos, o carga el namespace desde la página que los necesite:\n'
            '${huerfanos.join(', ')}',
      );
    }
  });
}
