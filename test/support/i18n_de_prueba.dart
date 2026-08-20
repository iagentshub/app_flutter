import 'dart:convert';
import 'dart:io';

import 'package:app_flutter/utils/i18n.dart';

/// Registra los locales reales para que `tr()` devuelva en los tests el mismo
/// texto que ve el usuario.
///
/// Antes cada test inyectaba un `tx` que devolvía el *fallback* de la llamada,
/// así que comprobaba el texto escrito en el widget y no el del JSON: si los
/// dos se separaban —y se separaban— el test seguía en verde con el texto
/// equivocado. Ahora lee `assets/locales/`, con lo que además falla si la clave
/// no está declarada.
///
/// Se lee con `dart:io` y no con `rootBundle` porque los tests corren en la VM
/// y el bundle de assets no está montado.
void cargarTraduccionesDePrueba({String idioma = 'es'}) {
  I18n.limpiar();
  for (final f in Directory(
    'assets/locales/$idioma',
  ).listSync().whereType<File>()) {
    final namespace = f.uri.pathSegments.last.replaceAll('.json', '');
    I18n.registrar(
      namespace,
      jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
    );
  }
}
