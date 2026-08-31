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
    final declaradas = <String, Set<String>>{};
    for (final idioma in const ['es', 'en']) {
      final claves = <String>{};
      for (final f in Directory(
        'assets/locales/$idioma',
      ).listSync().whereType<File>()) {
        final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
        claves.addAll(_aplanar(json));
      }
      declaradas[idioma] = claves;
    }

    final sinDeclarar = _clavesUsadas()
        .where((c) => !declaradas['es']!.contains(c))
        .toSet();

    expect(
      sinDeclarar.toList()..sort(),
      isEmpty,
      reason:
          'Estas claves no están en assets/locales/es/: la app enseñará su\n'
          'fallback en español a todo el mundo, también en inglés.\n'
          '${(sinDeclarar.toList()..sort()).join('\n')}',
    );
  });

  /// Que la clave exista en *algún* fichero no basta: `tr()` solo ve los
  /// namespaces que alguien haya cargado. La pantalla de login carga `auth`,
  /// así que `tr('auth.identifier_required')` —declarado en `resources.json`—
  /// enseñaba el identificador en el campo de usuario, y lo mismo el aviso de
  /// «próximamente». El test de arriba no lo veía porque funde los seis
  /// ficheros en un único conjunto y pierde de vista de cuál salió cada clave.
  ///
  /// La regla que lo cierra: **si el primer tramo del id es el nombre de un
  /// namespace, la clave vive en ese fichero**. Una clave `auth.x` guardada en
  /// `resources.json` solo se resuelve mientras `resources` esté cargado, que
  /// es justo lo que no ocurre en las pantallas de auth.
  test('una clave con prefijo de namespace vive en ese namespace', () {
    final porNamespace = <String, Set<String>>{};
    for (final f in Directory(
      'assets/locales/es',
    ).listSync().whereType<File>()) {
      final namespace = f.uri.pathSegments.last.replaceAll('.json', '');
      final json = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      porNamespace[namespace] = _aplanar(json).toSet();
    }

    final descolocadas = <String>{};
    for (final clave in _clavesUsadas(soloGlobales: true)) {
      final prefijo = clave.split('.').first;
      if (!porNamespace.containsKey(prefijo)) continue; // no es un namespace
      final donde = porNamespace.entries
          .where((e) => e.value.contains(clave))
          .map((e) => e.key)
          .toSet();
      if (donde.isNotEmpty && !donde.contains(prefijo)) {
        descolocadas.add('$clave → declarada en ${donde.join(', ')}');
      }
    }

    expect(
      descolocadas.toList()..sort(),
      isEmpty,
      reason:
          'Estas claves solo se resuelven si además está cargado el namespace\n'
          'donde viven, no el que anuncia su prefijo. Muévelas a su fichero.\n'
          '${(descolocadas.toList()..sort()).join('\n')}',
    );
  });

  test('detecta literales visibles que no pasan por i18n', () {
    const ejemplo = """
Text('Guardar')
tooltip: 'Actualizar'
showMessage('Operación terminada')
_error = 'No se pudo cargar'
this.busyLabel = 'En curso'
""";

    expect(
      _literalesVisibles(ejemplo).map((item) => item.literal),
      containsAll(<String>[
        'Guardar',
        'Actualizar',
        'Operación terminada',
        'No se pudo cargar',
        'En curso',
      ]),
    );
  });

  test('el código de producción no contiene textos visibles hardcodeados', () {
    final hallazgos = <String>[];
    for (final archivo in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!archivo.path.endsWith('.dart')) continue;
      final lineas = archivo.readAsLinesSync();
      for (var indice = 0; indice < lineas.length; indice++) {
        for (final item in _literalesVisibles(lineas[indice])) {
          if (_esLiteralTecnico(item.literal)) continue;
          hallazgos.add(
            '${archivo.path}:${indice + 1}: ${item.sink} → ${item.literal}',
          );
        }
      }
    }

    expect(
      hallazgos,
      isEmpty,
      reason:
          'Estos textos llegan a la interfaz sin pasar por tr/_tx/tx. '
          'Añade una clave ES/EN y pásala al widget.\n${hallazgos.join('\n')}',
    );
  });
}

typedef _LiteralVisible = ({String sink, String literal});

Iterable<_LiteralVisible> _literalesVisibles(String fuente) sync* {
  final patrones = <({String sink, RegExp patron})>[
    (
      sink: 'Text',
      patron: RegExp(
        r'''\b(?:Text|SelectableText)\(\s*(?:const\s+)?(['"])(.*?)\1''',
      ),
    ),
    (
      sink: 'propiedad visible',
      patron: RegExp(
        r'''\b(?:tooltip|labelText|hintText|helperText|errorText|semanticLabel|cancelLabel|confirmLabel|retryLabel|emptyText)\s*:\s*(['"])(.*?)\1''',
      ),
    ),
    (
      sink: 'showMessage',
      patron: RegExp(r'''\bshowMessage\(\s*(['"])(.*?)\1'''),
    ),
    (
      sink: 'estado de error',
      patron: RegExp(r'''\b_?error\s*=\s*(['"])(.*?)\1'''),
    ),
    (
      sink: 'valor por defecto visible',
      patron: RegExp(
        r'''\bthis\.[A-Za-z0-9_]*(?:Label|Tooltip|Text)\s*=\s*(['"])(.*?)\1''',
      ),
    ),
  ];

  final codigo = _sinComentarios(fuente);
  for (final entrada in patrones) {
    for (final match in entrada.patron.allMatches(codigo)) {
      yield (sink: entrada.sink, literal: match.group(2)!);
    }
  }
}

bool _esLiteralTecnico(String literal) {
  if (literal.isEmpty || literal.startsWith(r'$') || literal.startsWith('@')) {
    return true;
  }
  if (literal.startsWith('http://') ||
      literal.startsWith('https://') ||
      literal.startsWith('/api/')) {
    return true;
  }
  if (!RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(literal)) return true;
  return const {
    'GET',
    'POST',
    'DELETE',
    'generic',
    'claude',
    'openai',
    'github',
    'ollama',
    r'ID: ${item.id}',
    't (s)',
    's',
  }.contains(literal);
}

/// Todas las rutas de hoja de un bundle: `{"a":{"b":"x"}}` → `a.b`.
Iterable<String> _aplanar(Map<String, dynamic> m, [String pre = '']) sync* {
  for (final e in m.entries) {
    final ruta = '$pre${e.key}';
    final v = e.value;
    if (v is Map<String, dynamic>) {
      yield* _aplanar(v, '$ruta.');
    } else {
      yield ruta;
    }
  }
}

/// Las claves que el código pide: `tr('clave')`, `_txt(bundle, 'clave')`,
/// `.text('clave')` y `_tx('clave')`, el atajo de página sobre
/// `TranslatedTexts.text`. Sin este último el guardián no veía ninguna
/// pantalla que lo use: el rediseño de /register se subió con tres claves del
/// hero sin declarar y la página enseñaba «register.hero_headline» en el
/// titular.
///
/// Con [soloGlobales] quedan las que se resuelven **sin** bundle de página:
/// `tr()` y `trOr()`. Las otras tres formas llevan delante el bundle que la
/// pantalla acaba de cargar, así que una clave suya se encuentra ahí aunque su
/// prefijo anuncie otro namespace.
Set<String> _clavesUsadas({bool soloGlobales = false}) {
  final patrones = [
    RegExp(r"tr\(\s*'([a-zA-Z0-9_.]+)'"),
    if (!soloGlobales) ...[
      RegExp(r"_txt\(\s*\w+\s*,\s*'([a-zA-Z0-9_.]+)'"),
      RegExp(r"\.text\(\s*'([a-zA-Z0-9_.]+)'"),
      RegExp(r"_tx\(\s*'([a-zA-Z0-9_.]+)'"),
    ],
  ];
  final claves = <String>{};
  for (final f in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.dart')) continue;
    final texto = _sinComentarios(f.readAsStringSync());
    for (final p in patrones) {
      claves.addAll(p.allMatches(texto).map((m) => m.group(1)!));
    }
  }
  return claves;
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
