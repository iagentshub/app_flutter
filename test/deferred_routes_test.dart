import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El bundle web se descarga entero antes de la pantalla de login, así que las
/// áreas pesadas que usa una minoría —admin con Centinel, el editor visual de
/// workflows, el checkout de Stripe— viajan en partes diferidas.
///
/// El diferido se deshace solo: basta con que **otro** fichero importe una de
/// esas librerías sin `deferred`, y dart2js devuelve su código al bundle
/// principal sin que ningún test de comportamiento se entere. Estos dos tests
/// son el guardarraíl.
void main() {
  final router = File('lib/app/router/internal_router.dart');

  /// Las librerías que tienen que llegar por partes, con el prefijo esperado.
  const diferidas = <String, String>{
    'features/admin/pages/admin_page.dart': 'admin_page',
    'features/admin/pages/centinel_page.dart': 'centinel_page',
    'features/admin/pages/metadata_page.dart': 'metadata_page',
    'features/workflows/pages/workflows_page.dart': 'workflows_page',
    'features/public/pages/checkout_page.dart': 'checkout_page',
  };

  test('el router importa las áreas pesadas con deferred as', () {
    final fuente = router.readAsStringSync();
    final sinDiferir = <String>[];

    for (final entrada in diferidas.entries) {
      final ruta = entrada.key.replaceFirst('features/', '../../features/');
      final esperado = RegExp(
        "import\\s+'${RegExp.escape(ruta)}'\\s*\\n?\\s*deferred\\s+as\\s+${entrada.value}\\s*;",
      );
      if (!esperado.hasMatch(fuente)) sinDiferir.add(entrada.key);
    }

    expect(
      sinDiferir,
      isEmpty,
      reason:
          'Estas rutas volvieron al bundle principal. Impórtalas con\n'
          "`deferred as` y móntalas con DeferredPage:\n${sinDiferir.join('\n')}",
    );
  });

  test('nadie más importa una librería diferida sin diferir', () {
    final infractores = <String>[];

    for (final fichero
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!fichero.path.endsWith('.dart')) continue;
      final normalizada = fichero.path.replaceAll(r'\', '/');
      // El propio router es quien las importa, y una librería diferida puede
      // importar a sus vecinas: dentro de la misma parte no hay nada que
      // proteger.
      if (normalizada == router.path) continue;

      final lineas = fichero.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        if (!linea.startsWith('import ')) continue;
        for (final destino in diferidas.keys) {
          final hoja = destino.split('/').last;
          if (!linea.contains("/$hoja'") && !linea.contains("/$hoja\"")) {
            continue;
          }
          if (!_apuntaA(normalizada, linea, destino)) continue;
          if (linea.contains('deferred as')) continue;
          infractores.add('$normalizada:${i + 1}');
        }
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'Un import normal a una página diferida la devuelve al bundle\n'
          'principal y anula la carga diferida:\n${infractores.join('\n')}',
    );
  });

  test('cada DeferredPage del router nombra su propio prefijo', () {
    final fuente = router.readAsStringSync();
    final montadas = RegExp(
      r"name:\s*'([a-z_]+)',\s*\n\s*loader:\s*([a-z_]+)\.loadLibrary",
    ).allMatches(fuente);

    expect(
      montadas.length,
      diferidas.length,
      reason:
          'Cada librería diferida se monta con un DeferredPage; hay '
          '${montadas.length} para ${diferidas.length} importaciones.',
    );
    for (final montada in montadas) {
      expect(
        montada.group(1),
        montada.group(2),
        reason:
            'El `name` del DeferredPage identifica la parte en los '
            'diagnósticos: tiene que ser el prefijo del `deferred as`.',
      );
    }
  });
}

/// ¿La ruta relativa de [linea], resuelta desde [origen], es [destino]?
bool _apuntaA(String origen, String linea, String destino) {
  final entrecomillado = RegExp("import\\s+'([^']+)'").firstMatch(linea);
  if (entrecomillado == null) return false;
  final objetivo = entrecomillado.group(1)!;
  if (objetivo.startsWith('package:') || objetivo.startsWith('dart:')) {
    return false;
  }
  final base = origen.substring(0, origen.lastIndexOf('/'));
  final partes = <String>[...base.split('/'), ...objetivo.split('/')];
  final resuelta = <String>[];
  for (final parte in partes) {
    if (parte == '.' || parte.isEmpty) continue;
    if (parte == '..') {
      if (resuelta.isNotEmpty) resuelta.removeLast();
      continue;
    }
    resuelta.add(parte);
  }
  return resuelta.join('/') == 'lib/$destino';
}
