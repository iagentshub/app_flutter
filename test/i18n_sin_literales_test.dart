import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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

  test('ningún fichero de locales repite una clave dentro del mismo objeto', () {
    final repetidas = <String>[];

    for (final idioma in ['es', 'en']) {
      for (final fichero in Directory(
        'assets/locales/$idioma',
      ).listSync().whereType<File>()) {
        if (!fichero.path.endsWith('.json')) continue;
        final nombre = fichero.uri.pathSegments.last;
        for (final duplicada in _clavesRepetidas(fichero.readAsStringSync())) {
          repetidas.add('$idioma/$nombre:${duplicada.linea} → ${duplicada.ruta}');
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
  });

  test('las pantallas auditadas no introducen literales directos en UI', () {
    const auditedFiles = [
      'lib/features/public/pages/checkout_page.dart',
      'lib/features/public/pages/not_found_page.dart',
      'lib/features/billing/widgets/payment_element_stub.dart',
      'lib/features/knowledge/dialogs/add_url_dialog.dart',
      'lib/features/knowledge/dialogs/add_text_dialog.dart',
      'lib/features/knowledge/dialogs/skill_form_dialog.dart',
      'lib/features/agents/widgets/chat_composer.dart',
      'lib/features/connections/dialogs/connection_form_dialog.dart',
    ];
    final violations = <String>[];

    for (final path in auditedFiles) {
      final source = File(path).readAsStringSync();
      final unit = parseString(content: source, path: path).unit;
      unit.accept(_UiLiteralVisitor(path, source, violations));
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Pasa cada texto visible por tx/_tx y añade la clave a ambos locales:\n'
          '${violations.join('\n')}',
    );
  });
}

class _UiLiteralVisitor extends RecursiveAstVisitor<void> {
  _UiLiteralVisitor(this.path, this.source, this.violations);

  final String path;
  final String source;
  final List<String> violations;

  static const _namedSinks = {
    'InputDecoration': {'labelText', 'hintText', 'helperText', 'errorText'},
    'Tooltip': {'message'},
    'Semantics': {'label', 'value', 'hint'},
  };

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type.name.lexeme;
    final arguments = node.argumentList.arguments;
    if (type == 'Text' && arguments.isNotEmpty) {
      _recordIfLiteral(arguments.first);
    }
    final names = _namedSinks[type];
    if (names != null) {
      for (final argument in arguments.whereType<NamedExpression>()) {
        if (names.contains(argument.name.label.name)) {
          _recordIfLiteral(argument.expression);
        }
      }
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitReturnStatement(ReturnStatement node) {
    _recordIfLiteral(node.expression);
    super.visitReturnStatement(node);
  }

  void _recordIfLiteral(Expression? expression) {
    if (expression is! SimpleStringLiteral || expression.value.isEmpty) return;
    final line =
        '\n'.allMatches(source.substring(0, expression.offset)).length + 1;
    violations.add('$path:$line → ${expression.value}');
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
      while (siguiente < fuente.length &&
          fuente[siguiente].trim().isEmpty) {
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
