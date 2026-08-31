import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_de_prueba.dart';

/// Había 34 llamadas a `showMessage('…')` con el texto escrito en español
/// dentro del código —«Agente guardado», «No se pudo eliminar la skill»— más
/// los títulos y botones de los diálogos de borrado. Un usuario con la app en
/// inglés los leía en español, porque se habían saltado el patrón
/// `tr(clave, fallback)` que sigue el resto de la app.
void main() {
  setUp(cargarTraduccionesDePrueba);

  test('ningún mensaje de usuario se escribe suelto en el código', () {
    final sueltos = <String>[];
    // `showMessage('...')` sin pasar por tr: el primer argumento sería el
    // texto literal en vez de una clave traducida. Una interpolación que
    // contiene traducciones —`showMessage('${tr('a')}: $n')`— sí vale.
    final literal = RegExp(r"showMessage\(\s*'");
    final traduce = RegExp(r"(?<![A-Za-z0-9_.])(trOr?|_?tx\w*)\(");

    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (literal.hasMatch(lineas[i]) && !traduce.hasMatch(lineas[i])) {
          sueltos.add('${f.path}:${i + 1}');
        }
      }
    }

    expect(
      sueltos,
      isEmpty,
      reason:
          'Pasa el mensaje por tr(clave) y añade la clave a\n'
          'assets/locales/{es,en}/:\n${sueltos.join('\n')}',
    );
  });

  test('el idioma no se decide con un booleano en las pantallas ya limpias', () {
    // `isEnglish ? 'Sign in' : 'Entrar'` como fallback da por hecho que los
    // idiomas son exactamente dos: al añadir un tercero a
    // `supportedLanguageCodes` no falla nada — simplemente nunca se llega a él,
    // que es la peor forma de fallar. El patrón del resto de la app es un solo
    // fallback en el idioma base y la traducción en `assets/locales/`.
    //
    // `features/public` entró aquí al borrarse las cinco páginas que llevaban
    // 29 ternarios: eran la versión Flutter de un sitio que sirve React y no las
    // montaba ninguna ruta, así que no había nada que traducir.
    //
    // `features/profile` entró al derivar sus dos selectores de la lista que
    // toca: el de la interfaz de `LocaleController.supportedLanguageCodes` y el
    // de idiomas de contenido de `ContentLanguages`. Escribía dos opciones a
    // mano en cada uno, y el segundo dejaba fuera siete idiomas que el backend
    // sí acepta.
    final limpias = [
      'lib/features/auth',
      'lib/features/profile',
      'lib/features/public',
      'lib/shared/widgets',
      'lib/shared/i18n',
      'lib/shared/state',
    ];
    // Dos disfraces del mismo error: el booleano con nombre y la comparación
    // suelta contra un código concreto. El segundo se me escapó al escribir
    // esta guarda y estaba vivo en el footer del sidebar, con un campo de ruta
    // por idioma detrás.
    final ternario = RegExp(
      r"[iI]sEnglish\s*(\?|$)|"
      r"[Ll]anguageCode\s*==\s*'(?!\$)[a-z]{2}'\s*(\?|$)",
    );
    final reincidentes = <String>[];

    for (final raiz in limpias) {
      for (final f in Directory(
        raiz,
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        final lineas = f.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          final linea = lineas[i];
          if (linea.trimLeft().startsWith('//') ||
              linea.trimLeft().startsWith('///')) {
            continue;
          }
          if (ternario.hasMatch(linea)) reincidentes.add('${f.path}:${i + 1}');
        }
      }
    }

    expect(
      reincidentes,
      isEmpty,
      reason:
          'Usa el código de idioma (LocaleController.supportedLanguageCodes) y\n'
          'un único fallback en el idioma base:\n${reincidentes.join('\n')}',
    );
  });

  test('ningún texto en español se queda escrito en el código', () {
    // El barrido ancho: cualquier cadena con acentos o artículos españoles
    // dentro de `lib/`. Los fallbacks se llevaron por delante la mayoría, pero
    // quedaban 46 que nunca habían pasado por i18n —las validaciones de los
    // formularios de acceso, los errores del chat, «Próximamente»— y en inglés
    // se veían en español.
    //
    // Se excluyen dos cosas, y solo dos: los mensajes de excepción, que el
    // usuario no lee (van a `throw`/`assert`, y lo que ve es otro texto), y los
    // nombres nativos de los idiomas, que por definición no se traducen.
    final literal = RegExp(r"'((?:[^'\\\n]|\\.){4,})'");
    final clave = RegExp(r'^[a-z0-9_.]+$');
    final ruta = RegExp(r'^(https?:|/|assets/|package:|dart:)');
    final espanol = RegExp(
      // Las mayúsculas acentuadas se listan una a una: el rango «Á-Ú» incluye
      // el signo × (U+00D7) y colaba el multiplicador de los ciclos.
      "[áéíóúñ¿¡ÁÉÍÓÚÑ]|\\b(el|la|los|las|de|para|con|sin|que|una|este|esta)\\b",
      caseSensitive: false,
    );
    final excepcion = RegExp(
      r'throw |StateError|ArgumentError|assert\(|Exception\(|debugPrint',
    );
    const nombresDeIdioma = {'Español', 'Français', 'Português', 'English'};

    final sueltos = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final lineas = f.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        final limpia = linea.trimLeft();
        if (limpia.startsWith('//') || limpia.startsWith('*')) continue;
        if (linea.contains('import ') || limpia.startsWith('part ')) continue;
        if (excepcion.hasMatch(linea)) continue;
        for (final m in literal.allMatches(linea)) {
          final txt = m.group(1)!;
          if (clave.hasMatch(txt) || ruta.hasMatch(txt)) continue;
          if (nombresDeIdioma.contains(txt)) continue;
          if (!espanol.hasMatch(txt)) continue;
          sueltos.add('${f.path}:${i + 1}  «$txt»');
        }
      }
    }

    expect(
      sueltos,
      isEmpty,
      reason:
          'Texto de interfaz escrito en el código. Pásalo por tr(clave) y\n'
          'declara la clave en assets/locales/{es,en}/:\n${sueltos.join('\n')}',
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

  test(
    'ningún fichero de locales repite una clave dentro del mismo objeto',
    () {
      final repetidas = <String>[];

      for (final idioma in ['es', 'en']) {
        for (final fichero in Directory(
          'assets/locales/$idioma',
        ).listSync().whereType<File>()) {
          if (!fichero.path.endsWith('.json')) continue;
          final nombre = fichero.uri.pathSegments.last;
          for (final duplicada in _clavesRepetidas(
            fichero.readAsStringSync(),
          )) {
            repetidas.add(
              '$idioma/$nombre:${duplicada.linea} → ${duplicada.ruta}',
            );
          }
        }
      }

      expect(
        repetidas,
        isEmpty,
        reason:
            'jsonDecode se queda con la última y descarta la anterior sin avisar,\n'
            'así que la primera traducción nunca llega a la pantalla.\n'
            'Borra la que sobre:\n${repetidas.join('\n')}',
      );
    },
  );

  test('el AST de todo lib no contiene literales directos en UI', () {
    final violations = <String>[];

    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final path = file.path;
      final source = File(path).readAsStringSync();
      final unit = parseString(content: source, path: path).unit;
      unit.accept(_UiLiteralVisitor(path, source, violations));
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Pasa cada texto visible por tx/tr y añade la clave a ambos locales:\n'
          '${violations.join('\n')}',
    );
  });
}

class _UiLiteralVisitor extends RecursiveAstVisitor<void> {
  _UiLiteralVisitor(this.path, this.source, this.violations);

  final String path;
  final String source;
  final List<String> violations;

  static const _visibleArguments = {
    'tooltip',
    'labelText',
    'hintText',
    'helperText',
    'errorText',
    'semanticLabel',
    'cancelLabel',
    'confirmLabel',
    'retryLabel',
    'emptyText',
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.name.lexeme;
    final arguments = node.argumentList.arguments;
    if (type == 'Text' && arguments.isNotEmpty) {
      _recordIfLiteral(arguments.first);
    }
    for (final argument in arguments.whereType<NamedExpression>()) {
      if (_visibleArguments.contains(argument.name.label.name)) {
        _recordIfLiteral(argument.expression);
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    if (name == 'showMessage' && node.argumentList.arguments.isNotEmpty) {
      _recordIfLiteral(node.argumentList.arguments.first);
    }
    for (final argument
        in node.argumentList.arguments.whereType<NamedExpression>()) {
      if (_visibleArguments.contains(argument.name.label.name) ||
          (name == 'showConfirmActionDialog' &&
              {'title', 'message'}.contains(argument.name.label.name))) {
        _recordIfLiteral(argument.expression);
      }
    }
    super.visitMethodInvocation(node);
  }

  void _recordIfLiteral(Expression? expression) {
    if (expression == null) return;
    if (expression is ParenthesizedExpression) {
      _recordIfLiteral(expression.expression);
      return;
    }
    if (expression is ConditionalExpression) {
      _recordIfLiteral(expression.thenExpression);
      _recordIfLiteral(expression.elseExpression);
      return;
    }
    if (expression is BinaryExpression &&
        {'??', '+'}.contains(expression.operator.lexeme)) {
      if (expression.operator.lexeme == '+') {
        _recordIfLiteral(expression.leftOperand);
      }
      _recordIfLiteral(expression.rightOperand);
      return;
    }
    if (expression is StringInterpolation) {
      for (final element
          in expression.elements.whereType<InterpolationString>()) {
        _recordValue(element.value, element.offset);
      }
      return;
    }
    if (expression is SimpleStringLiteral) {
      _recordValue(expression.value, expression.offset);
    }
  }

  void _recordValue(String value, int offset) {
    final literal = value.trim();
    if (_isTechnicalLiteral(literal)) return;
    final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
    violations.add('$path:$line → $literal');
  }

  bool _isTechnicalLiteral(String value) {
    if (value.isEmpty || !RegExp(r'[A-Za-zÀ-ÿ]').hasMatch(value)) return true;
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('/api/')) {
      return true;
    }
    return const {
      'GET',
      'POST',
      'DELETE',
      'generic',
      'claude',
      'openai',
      'github',
      'ollama',
      'ID:',
      't (s)',
      's',
      'ms',
    }.contains(value);
  }
}

class _ClaveRepetida {
  const _ClaveRepetida(this.ruta, this.linea);

  final String ruta;
  final int linea;
}

/// Ámbito abierto mientras se recorre el JSON: un objeto lleva la cuenta de las
/// claves ya vistas en él; los arrays solo sirven para no confundir sus cadenas
/// con claves.
class _Ambito {
  _Ambito({required this.esObjeto, required this.prefijo});

  final bool esObjeto;
  final String prefijo;
  final Set<String> vistas = {};
  String? ultimaClave;
}

/// Busca claves repetidas dentro de un mismo objeto recorriendo el texto en
/// crudo: `jsonDecode` las colapsa en silencio, así que hay que mirar antes de
/// parsear. Una cadena es clave cuando el ámbito abierto es un objeto y tras
/// ella viene `:` —un valor siempre va seguido de `,`, `}` o `]`—.
List<_ClaveRepetida> _clavesRepetidas(String fuente) {
  final repetidas = <_ClaveRepetida>[];
  final pila = <_Ambito>[];
  var i = 0;

  while (i < fuente.length) {
    final caracter = fuente[i];
    if (caracter == '{' || caracter == '[') {
      final padre = pila.isEmpty ? null : pila.last;
      final clave = padre?.ultimaClave;
      pila.add(
        _Ambito(
          esObjeto: caracter == '{',
          prefijo: clave == null
              ? (padre?.prefijo ?? '')
              : '${padre!.prefijo}$clave.',
        ),
      );
      i++;
    } else if (caracter == '}' || caracter == ']') {
      if (pila.isNotEmpty) pila.removeLast();
      i++;
    } else if (caracter == '"') {
      final fin = _finDeCadena(fuente, i);
      final ambito = pila.isEmpty ? null : pila.last;
      var siguiente = fin;
      while (siguiente < fuente.length && fuente[siguiente].trim().isEmpty) {
        siguiente++;
      }
      final esClave =
          ambito != null &&
          ambito.esObjeto &&
          siguiente < fuente.length &&
          fuente[siguiente] == ':';
      if (esClave) {
        final clave = fuente.substring(i + 1, fin - 1);
        if (!ambito.vistas.add(clave)) {
          repetidas.add(
            _ClaveRepetida(
              '${ambito.prefijo}$clave',
              '\n'.allMatches(fuente.substring(0, i)).length + 1,
            ),
          );
        }
        ambito.ultimaClave = clave;
      }
      i = fin;
    } else {
      i++;
    }
  }

  return repetidas;
}

/// Índice justo después de la comilla de cierre de la cadena que empieza en
/// [inicio], saltándose los caracteres escapados (`\"`, `\\`).
int _finDeCadena(String fuente, int inicio) {
  var i = inicio + 1;
  while (i < fuente.length) {
    final caracter = fuente[i];
    if (caracter == r'\') {
      i += 2;
      continue;
    }
    if (caracter == '"') return i + 1;
    i++;
  }
  return fuente.length;
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
