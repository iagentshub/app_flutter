import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_de_prueba.dart';

/// El tercer argumento de `tr('clave', 'texto')` es un **fallback**, no la
/// traducción: solo se usa si la clave falta en `assets/locales/`. Por eso una
/// clave que nadie declaró no rompe nada — la app enseña el fallback, que está
/// escrito en español, y lo hace también con la interfaz en inglés.
///
/// Así se colaron 24: `common.activate`, `common.deactivate`, `common.inactive`
/// (los botones de activar y desactivar recursos, en cuatro pantallas), el
/// historial de ejecuciones de workflows entero, y el grafo de Explorar. Nadie
/// lo vio porque en español se ve bien.
void main() {
  setUp(cargarTraduccionesDePrueba);

  test('toda clave que usa el código existe en los locales', () {
    Iterable<String> aplanar(Map<String, dynamic> m, [String pre = '']) sync* {
      for (final e in m.entries) {
        final ruta = '$pre${e.key}';
        final v = e.value;
        if (v is Map<String, dynamic>) {
          yield* aplanar(v, '$ruta.');
        } else {
          yield ruta;
        }
      }
    }

    final declaradas = <String, Set<String>>{};
    for (final idioma in const ['es', 'en']) {
      final claves = <String>{};
      for (final f in Directory(
        'assets/locales/$idioma',
      ).listSync().whereType<File>()) {
        final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        claves.addAll(aplanar(json));
      }
      declaradas[idioma] = claves;
    }

    // `tr('clave', …)`, `_txt(bundle, 'clave', …)` y `.text('clave', …)`.
    final patrones = [
      RegExp(r"tr\(\s*'([a-zA-Z0-9_.]+)'"),
      RegExp(r"_txt\(\s*\w+\s*,\s*'([a-zA-Z0-9_.]+)'"),
      RegExp(r"\.text\(\s*'([a-zA-Z0-9_.]+)'"),
      // `_tx('clave')`, el atajo de página sobre `TranslatedTexts.text`. Sin
      // esto el guardián no veía ninguna pantalla que lo use: el rediseño de
      // /register se subió con tres claves del hero sin declarar y la página
      // enseñaba «register.hero_headline» en el titular.
      RegExp(r"_tx\(\s*'([a-zA-Z0-9_.]+)'"),
    ];

    final sinDeclarar = <String>{};
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final texto = _sinComentarios(f.readAsStringSync());
      for (final p in patrones) {
        for (final m in p.allMatches(texto)) {
          final clave = m.group(1)!;
          if (!declaradas['es']!.contains(clave)) sinDeclarar.add(clave);
        }
      }
    }

    expect(
      sinDeclarar.toList()..sort(),
      isEmpty,
      reason:
          'Estas claves no están en assets/locales/es/: la app enseñará su\n'
          'fallback en español a todo el mundo, también en inglés.\n'
          '${(sinDeclarar.toList()..sort()).join('\n')}',
    );
  });
}

/// Los ejemplos de los comentarios no son llamadas: `i18n.dart` documenta
/// `_tx('clave')` en su propio docstring, y sin quitarlos el guardián exige
/// declarar una clave llamada «clave».
String _sinComentarios(String src) => src
    .split('\n')
    .map((linea) {
      final i = linea.indexOf('//');
      if (i < 0) return linea;
      if (i > 0 && linea[i - 1] == ':') return linea; // http://
      return linea.substring(0, i);
    })
    .join('\n');
