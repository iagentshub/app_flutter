import 'dart:convert';

import 'package:flutter/services.dart';

import '../../utils/i18n.dart';

abstract final class LocaleLoader {
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> load({
    required String languageCode,
    required String namespace,
  }) async {
    final locale = languageCode;
    final key = '$locale/$namespace';
    final cached = _cache[key];
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(
      'assets/locales/$locale/$namespace.json',
    );
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      _cache[key] = decoded;
      return decoded;
    }
    return <String, dynamic>{};
  }

  /// Traducción de [path] en un bundle concreto.
  ///
  /// La resolución vive en `utils/i18n.dart`, que es donde puede llegar
  /// cualquier widget sin recibir el bundle por parámetro. Esto se queda para
  /// quien ya tiene el bundle en la mano.
  static String text(Map<String, dynamic> bundle, String path) =>
      I18n.resolveEn(bundle, path);

  /// Un nodo del bundle que no es una cadena sino un diccionario de ellas.
  ///
  /// Lo pedía la lista de países del checkout: 45 nombres traducidos que son
  /// datos, no copia de interfaz, y que con `text()` habrían obligado a
  /// escribir 45 rutas a mano en el widget.
  static Map<String, String> map(Map<String, dynamic> bundle, String path) {
    dynamic current = bundle;
    for (final segment in path.split('.')) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return const {};
      }
    }
    if (current is! Map) return const {};
    return {
      for (final entry in current.entries)
        if (entry.value is String) '${entry.key}': entry.value as String,
    };
  }
}
