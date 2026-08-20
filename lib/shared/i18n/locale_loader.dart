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
}
