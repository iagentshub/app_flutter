import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Había 34 llamadas a `showMessage('…')` con el texto escrito en español
/// dentro del código —«Agente guardado», «No se pudo eliminar la skill»— más
/// los títulos y botones de los diálogos de borrado. Un usuario con la app en
/// inglés los leía en español, porque se habían saltado el patrón
/// `_tx(clave, fallback)` que sigue el resto de la app.
void main() {
  test('ningún mensaje de usuario se escribe suelto en el código', () {
    final sueltos = <String>[];
    // `showMessage('...')` sin pasar por _tx: el primer argumento sería el
    // texto literal en vez de una clave traducida.
    final literal = RegExp(r"showMessage\(\s*'");

    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (literal.hasMatch(lineas[i])) sueltos.add('${f.path}:${i + 1}');
      }
    }

    expect(
      sueltos,
      isEmpty,
      reason:
          'Pasa el mensaje por _tx(clave, fallback) y añade la clave a\n'
          'assets/locales/{es,en}/:\n${sueltos.join('\n')}',
    );
  });

  test('cada clave de es tiene su equivalente en en', () {
    final faltan = <String>[];

    for (final esFile in Directory(
      'assets/locales/es',
    ).listSync().whereType<File>()) {
      if (!esFile.path.endsWith('.json')) continue;
      final nombre = esFile.uri.pathSegments.last;
      final enFile = File('assets/locales/en/$nombre');
      if (!enFile.existsSync()) {
        faltan.add('en/$nombre (el fichero entero)');
        continue;
      }
      final es = jsonDecode(esFile.readAsStringSync()) as Map<String, dynamic>;
      final en = jsonDecode(enFile.readAsStringSync()) as Map<String, dynamic>;
      _comparar(es, en, '$nombre:', faltan);
    }

    expect(
      faltan,
      isEmpty,
      reason: 'Traduce también al inglés:\n${faltan.join('\n')}',
    );
  });
}

/// Recorre el árbol de claves de [es] comprobando que [en] tiene las mismas.
/// Solo mira en esa dirección: el español es el idioma de referencia.
void _comparar(
  Map<String, dynamic> es,
  Map<String, dynamic> en,
  String prefijo,
  List<String> faltan,
) {
  for (final entrada in es.entries) {
    final valorEn = en[entrada.key];
    if (valorEn == null) {
      faltan.add('$prefijo${entrada.key}');
      continue;
    }
    if (entrada.value is Map<String, dynamic> &&
        valorEn is Map<String, dynamic>) {
      _comparar(
        entrada.value as Map<String, dynamic>,
        valorEn,
        '$prefijo${entrada.key}.',
        faltan,
      );
    }
  }
}
