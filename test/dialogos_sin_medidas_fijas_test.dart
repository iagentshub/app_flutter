import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Un `content: SizedBox(width: 760, height: 520)` cabe en el escritorio donde
/// se escribió y en ningún otro sitio: en un móvil de 360 px el diálogo
/// desborda por los lados y en una ventana de 600 px de alto recorta las
/// acciones. `dialogContentWidth` y `dialogContentHeight` (en
/// `responsive_dialog.dart`) ya lo resolvían en cincuenta diálogos; los cinco
/// que quedaban con medidas literales —revisión de importación oficial, sus
/// relaciones, historial de ejecuciones, historial de Centinel y la vista
/// rápida del grafo— pasan por ahí. Esto evita el sexto.
void main() {
  test('el contenido de un diálogo no lleva medidas literales', () {
    final literales = RegExp(r'content: SizedBox\(\s*(?:width|height): \d');
    final ofensores = <String>[];

    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in literales.allMatches(src)) {
        final linea = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        ofensores.add('${f.path}:$linea');
      }
    }

    expect(
      ofensores,
      isEmpty,
      reason:
          'Usa dialogContentWidth / dialogContentHeight:\n'
          '${ofensores.join('\n')}',
    );
  });
}
