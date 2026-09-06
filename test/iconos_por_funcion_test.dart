import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Una misma función tenía varios dibujos según la pantalla: el editor de
/// workflows guardaba con `check_rounded` y ejecutaba con `play_arrow_rounded`
/// mientras el formulario de agente, el editor de orquestaciones y Centinel
/// usaban `check` y `play_arrow`; el compositor del constructor enviaba con
/// una flecha y detenía con `stop_rounded` cuando el chat de agentes lo hacía
/// con `send` y `stop`.
///
/// Aquí solo se persiguen las variantes ya retiradas. Las familias `_rounded`
/// que siguen en uso —campana, cerrar sesión, avisos, flechas de plegado— son
/// un icono por función y no se tocan.
void main() {
  test('cada función de acción conserva un solo icono', () {
    const canonico = {
      'Icons.play_arrow_rounded': 'Icons.play_arrow',
      'Icons.check_rounded': 'Icons.check',
      'Icons.add_rounded': 'Icons.add',
      'Icons.copy_rounded': 'Icons.copy_outlined',
      'Icons.stop_rounded': 'Icons.stop',
      'Icons.arrow_upward_rounded': 'Icons.send',
      'Icons.close_rounded': 'Icons.close',
      'Icons.info_outline_rounded': 'Icons.info_outline',
      'Icons.tune_outlined': 'Icons.tune',
      'Icons.sync_outlined': 'Icons.sync',
    };
    final iconos = RegExp(r'\bIcons\.\w+');
    final reaparecidos = <String>[];

    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in iconos.allMatches(src)) {
        final usado = m.group(0)!;
        final bueno = canonico[usado];
        if (bueno == null) continue;
        final linea = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        reaparecidos.add('${f.path}:$linea usa $usado; esa función va con $bueno');
      }
    }

    expect(reaparecidos, isEmpty, reason: reaparecidos.join('\n'));
  });
}
