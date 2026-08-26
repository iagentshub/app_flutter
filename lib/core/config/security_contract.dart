enum SecurityCookieId {
  csrf('ga_csrf'),
  access('ga_token'),
  refresh('ga_refresh');

  const SecurityCookieId(this.value);

  final String value;
}

/// Contrato interno de nombres y formatos usados por la seguridad HTTP.
///
/// No es configuración administrable: cambiarlo en ejecución desalinearía la
/// app y el backend y podría dejar de enviar la protección CSRF.
abstract final class SecurityContract {
  static final Map<SecurityCookieId, RegExp> _cookiePatterns = {
    for (final cookie in SecurityCookieId.values)
      cookie: RegExp('(?:^|[;,]\\s*)${RegExp.escape(cookie.value)}=([^;,]*)'),
  };

  static RegExp getCookiePattern(SecurityCookieId id) => _cookiePatterns[id]!;

  static String? readCookieValue(
    String source,
    SecurityCookieId id, {
    bool decode = false,
  }) {
    final value = getCookiePattern(id).firstMatch(source)?.group(1);
    if (value == null || value.isEmpty) return null;
    return decode ? Uri.decodeComponent(value) : value;
  }
}
