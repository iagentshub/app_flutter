import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final featureFiles = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();
  final pages = featureFiles
      .where((file) => file.path.replaceAll(r'\', '/').contains('/pages/'))
      .toList();
  final presentationFiles = [
    ...featureFiles,
    ...Directory('lib/shared/widgets')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart')),
  ];

  test('las páginas coordinadoras no vuelven a crecer sin límite', () {
    final oversized = <String>[];
    for (final page in pages) {
      final lines = page.readAsLinesSync().length;
      if (lines > 700) oversized.add('${page.path}: $lines líneas');
    }

    expect(
      oversized,
      isEmpty,
      reason:
          'Extrae cards, diálogos o secciones a su directorio de feature:\n'
          '${oversized.join('\n')}',
    );
  });

  test('los diálogos de feature no se declaran dentro de pages', () {
    final inlineDialogs = <String>[];
    final dialogClass = RegExp(r'^class\s+\w*Dialog(?:\s|<)');
    for (final page in pages) {
      final lines = page.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (dialogClass.hasMatch(lines[index])) {
          inlineDialogs.add('${page.path}:${index + 1}');
        }
      }
    }

    expect(
      inlineDialogs,
      isEmpty,
      reason:
          'Mueve cada diálogo a features/<feature>/dialogs:\n'
          '${inlineDialogs.join('\n')}',
    );
  });

  test('las cards reutilizables no se declaran dentro de pages', () {
    final inlineCards = <String>[];
    final cardClass = RegExp(r'^class\s+\w*Card(?:\s|<)');
    for (final page in pages) {
      final lines = page.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (cardClass.hasMatch(lines[index])) {
          inlineCards.add('${page.path}:${index + 1}');
        }
      }
    }

    expect(
      inlineCards,
      isEmpty,
      reason:
          'Mueve cada card a features/<feature>/cards:\n'
          '${inlineCards.join('\n')}',
    );
  });

  test('las features usan los componentes de botón de la aplicación', () {
    final directMaterialButtons = <String>[];
    final materialButton = RegExp(
      r'\b(?:ElevatedButton|FilledButton|OutlinedButton|TextButton|IconButton)'
      r'(?:\.icon|\.tonalIcon|\.outlined|\.filled|\.filledTonal)?\s*\(',
    );
    for (final file in featureFiles) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (materialButton.hasMatch(lines[index])) {
          directMaterialButtons.add('${file.path}:${index + 1}');
        }
      }
    }

    expect(
      directMaterialButtons,
      isEmpty,
      reason:
          'Usa los componentes de shared/widgets/buttons en las features:\n'
          '${directMaterialButtons.join('\n')}',
    );
  });

  test(
    'los componentes de presentación mantienen responsabilidades acotadas',
    () {
      final oversized = <String>[];
      for (final file in presentationFiles) {
        final lines = file.readAsLinesSync().length;
        if (lines > 600) oversized.add('${file.path}: $lines líneas');
      }

      expect(
        oversized,
        isEmpty,
        reason:
            'Divide estado, secciones o componentes cuando superen 600 líneas:\n'
            '${oversized.join('\n')}',
      );
    },
  );

  test('toda mutación del cliente HTTP avisa del recurso que tocó', () {
    // La invalidación vive en un solo sitio a propósito: si un método nuevo
    // llama a la caché por su cuenta, las pantallas montadas no se enteran del
    // cambio y vuelve la desincronización que el mixin resuelve.
    final fuente = File('lib/core/network/api_client.dart').readAsStringSync();
    final sueltas = RegExp(
      r'_cache\.invalidateForMutation\(',
    ).allMatches(fuente).length;

    expect(
      sueltas,
      1,
      reason:
          'Usa _afterMutation(path), que invalida la caché y emite el evento, '
          'en vez de llamar a la caché directamente.',
    );
  });

  test('quien muta no recarga por su cuenta', () {
    // Un `await _load()` justo detrás de una mutación es la señal de que la
    // pantalla no está escuchando el recurso: recarga lo suyo y deja a las
    // demás vistas con datos viejos.
    final infractores = <String>[];
    final recargaTrasMutar = RegExp(
      r'await _(repository|repositorio)\.\w+\([^;]*\);\s*\n\s*await _load\w*\(\)',
      multiLine: true,
    );
    for (final file in featureFiles) {
      final fuente = file.readAsStringSync();
      for (final match in recargaTrasMutar.allMatches(fuente)) {
        final linea =
            '\n'.allMatches(fuente.substring(0, match.start)).length + 1;
        infractores.add('${file.path}:$linea');
      }
    }

    expect(
      infractores,
      isEmpty,
      reason:
          'Usa el mixin WatchesResourceChanges en vez de recargar a mano tras '
          'mutar (ver CLAUDE.md):\n${infractores.join('\n')}',
    );
  });
}
