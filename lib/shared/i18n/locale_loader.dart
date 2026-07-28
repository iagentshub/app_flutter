import 'dart:convert';

import 'package:flutter/services.dart';

abstract final class LocaleLoader {
  static final Map<String, Map<String, dynamic>> _cache = {};

  static Future<Map<String, dynamic>> load({
    required bool isEnglish,
    required String namespace,
  }) async {
    final locale = isEnglish ? 'en' : 'es';
    final key = '$locale/$namespace';
    final cached = _cache[key];
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/locales/$locale/$namespace.json');
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      _cache[key] = decoded;
      return decoded;
    }
    return <String, dynamic>{};
  }

  static String text(
    Map<String, dynamic> bundle,
    String path, {
    String fallback = '',
  }) {
    dynamic current = bundle;
    for (final segment in path.split('.')) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return fallback;
      }
    }
    return current is String ? current : fallback;
  }

  static bool isEnglishRoute(String location) => location.startsWith('/en');
}
