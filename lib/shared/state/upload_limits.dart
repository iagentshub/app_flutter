/// Tamaño máximo de una petición al backend, en bytes. **0 = sin límite**.
///
/// El número lo decide el administrador (`max_request_bytes` en el panel) y
/// llega en `/api/settings/platform/public`, que la app ya consulta al
/// arrancar, en el login y cada vez que refresca los flags de plataforma.
/// Antes era una constante escrita a mano aquí —10 MB— que no coincidía ni con
/// el backend (2 MB) ni con nginx (1 MB, su valor por defecto): la interfaz
/// dejaba elegir un PDF de 4 MB y el usuario recibía un 413 en HTML que ni
/// siquiera mencionaba el tamaño.
///
/// Esto solo evita el viaje inútil: quien rechaza de verdad sigue siendo el
/// backend, que responde `payload_too_large` con `limit_bytes` dentro.
abstract final class UploadLimits {
  static int _maxRequestBytes = 0;

  /// Límite vigente en bytes, o 0 si no hay ninguno.
  static int get maxRequestBytes => _maxRequestBytes;

  static bool get unlimited => _maxRequestBytes <= 0;

  /// Si estos bytes no caben. Sin límite configurado siempre caben — comparar
  /// contra 0 a pelo rechazaría cualquier fichero, que es lo contrario.
  static bool exceeds(int bytes) => !unlimited && bytes > _maxRequestBytes;

  /// Se llama en los dos límites HTTP que reciben este ajuste: la lectura
  /// pública de `AuthRepository` y el guardado de `AdminPlatformRepository`.
  /// Así el cambio del administrador se aplica también en su sesión actual.
  static void updateFromPlatform(Map<String, dynamic> platform) {
    final raw = platform['max_request_bytes'];
    if (raw is int) {
      _maxRequestBytes = raw < 0 ? 0 : raw;
    } else if (raw is num) {
      _maxRequestBytes = raw < 0 ? 0 : raw.toInt();
    }
  }

  /// Para los mensajes de error: «10 MB», «512 KB»…
  static String get formatted => formatBytes(_maxRequestBytes);

  static String formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      final mb = bytes / (1024 * 1024);
      final texto = mb == mb.roundToDouble()
          ? mb.round().toString()
          : mb.toStringAsFixed(1);
      return '$texto MB';
    }
    if (bytes >= 1024) return '${(bytes / 1024).round()} KB';
    return '$bytes B';
  }
}
