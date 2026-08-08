import 'dart:io';

import 'package:app_flutter/shared/widgets/buttons/action_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Un botón que solo lleva un icono no tiene texto que leer: si no se le da un
/// nombre accesible, TalkBack y VoiceOver lo anuncian como «botón» y nada más.
///
/// Había once así, entre ellos el de mostrar/ocultar contraseña del login y los
/// de enviar y detener del chat. El nombre puede venir de tres sitios y los tres
/// valen: `tooltip:` en el propio botón, o un `Tooltip(...)` o `Semantics(...)`
/// que lo envuelva.
void main() {
  test('ningún botón de icono se queda sin nombre accesible', () {
    final sinNombre = <String>[];

    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = _sinComentarios(f.readAsStringSync());

      // `IconButton.styleFrom(` no es un botón, es un constructor de estilo.
      final botones = RegExp(r'\b(?:App)?IconButton(?:\.(?!styleFrom)\w+)?\(');
      for (final m in botones.allMatches(src)) {
        final fin = _cierreDe(src, m.end);
        final cuerpo = src.substring(m.end, fin);
        // `tooltip:` es un uso que lo pasa; `this.tooltip` es la declaración
        // del propio AppIconButton, que por definición lo expone.
        if (cuerpo.contains('tooltip:') || cuerpo.contains('this.tooltip')) {
          continue;
        }
        if (_envueltoEn(src, RegExp(r'\b(?:Tooltip|Semantics)\('), m.start, fin)) {
          continue;
        }
        final linea = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        sinNombre.add('${f.path}:$linea');
      }
    }

    expect(
      sinNombre,
      isEmpty,
      reason:
          'Añade tooltip: al botón, o envuélvelo en Tooltip/Semantics:\n'
          '${sinNombre.join('\n')}',
    );
  });

  /// El nombre accesible ya estaba cubierto; el tamaño del blanco se había
  /// quedado fuera. `ActionIconButton` es el botón de editar, eliminar,
  /// compartir e historial de todas las tarjetas —unos 40 usos— y medía
  /// 34x34, por debajo de los 48x48 que piden Material y la WCAG 2.5.5.
  testWidgets('el blanco táctil de ActionIconButton llega a 48x48', (
    tester,
  ) async {
    var pulsado = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ActionIconButton(
              icon: Icons.delete_outline,
              tooltip: 'Eliminar',
              onPressed: () => pulsado = true,
            ),
          ),
        ),
      ),
    );

    final size = tester.getSize(find.byType(ActionIconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    // Y el blanco es real, no solo hueco de layout: un toque a 22 px del
    // centro —fuera de los 34 px que se pintan— tiene que contar.
    final centro = tester.getCenter(find.byType(ActionIconButton));
    await tester.tapAt(centro + const Offset(22, 22));
    expect(pulsado, isTrue);

    // Lo que se ve no ha cambiado de tamaño: el icono sigue siendo de 18.
    final icono = tester.widget<Icon>(find.byType(Icon));
    expect(icono.size, 18);
  });
}

/// Quita los comentarios de línea, respetando `://` para no destrozar las URL.
///
/// Hace falta porque el primer intento buscaba «tooltip» a secas dentro del
/// cuerpo del botón, y un comentario que decía «Sin tooltip, un lector de
/// pantalla...» hacía pasar el test justo en el botón que lo había motivado.
/// Los paréntesis de un comentario también descuadran el conteo de _cierreDe.
String _sinComentarios(String src) => src
    .split('\n')
    .map((linea) {
      final i = linea.indexOf('//');
      if (i < 0) return linea;
      if (i > 0 && linea[i - 1] == ':') return linea; // http://
      return linea.substring(0, i);
    })
    .join('\n');

/// Índice justo después del paréntesis que cierra el abierto en [desde].
int _cierreDe(String src, int desde) {
  var profundidad = 1;
  var i = desde;
  while (i < src.length && profundidad > 0) {
    if (src[i] == '(') profundidad++;
    if (src[i] == ')') profundidad--;
    i++;
  }
  return i;
}

/// ¿Hay alguna apertura de [patron] anterior a [inicio] cuyo cierre caiga
/// después de [fin]? Es decir: ¿envuelve al botón?
bool _envueltoEn(String src, RegExp patron, int inicio, int fin) {
  for (final w in patron.allMatches(src.substring(0, inicio))) {
    if (_cierreDe(src, w.end) > fin) return true;
  }
  return false;
}
