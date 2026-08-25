/// Catálogo canónico de idiomas de contenido admitidos por los recursos.
abstract final class ContentLanguages {
  static const labelKeys = [
    'lang_es',
    'lang_en',
    'lang_fr',
    'lang_de',
    'lang_pt',
    'lang_it',
    'lang_zh',
    'lang_ja',
    'lang_ar',
  ];

  static final values = labelKeys
      .map((labelKey) => (code: codeFromLabel(labelKey)!, labelKey: labelKey))
      .toList(growable: false);
  static final codes = values.map((item) => item.code).toList(growable: false);
  static final _labelKeySet = labelKeys.toSet();

  static bool isLabel(Object? value) => _labelKeySet.contains(value);
  static String normalizeLabel(Object? value) {
    final label = value?.toString() ?? '';
    return isLabel(label) ? label : '';
  }

  static String labelKey(String code) => 'lang_${code.toLowerCase()}';
  static String? codeFromLabel(String key) =>
      labelKeys.contains(key) ? key.substring('lang_'.length) : null;
}
