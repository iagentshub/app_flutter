/// Resultado de la comprobación de backend hecha durante el splash de arranque,
/// para que la primera pantalla de login no tenga que repetirla.
///
/// Semántica de "consumir una vez": [consume] devuelve el snapshot solo la
/// primera vez que se llama tras [set] y lo limpia; cualquier visita
/// posterior al login (logout, cambio de backend) hace su propia comprobación
/// fresca en vez de reutilizar un resultado obsoleto.
abstract final class BootPlatformCache {
  static Map<String, dynamic>? _platform;
  static bool? _reachable;

  static void set({required Map<String, dynamic>? platform, required bool reachable}) {
    _platform = platform;
    _reachable = reachable;
  }

  static ({Map<String, dynamic>? platform, bool reachable})? consume() {
    if (_reachable == null) return null;
    final result = (platform: _platform, reachable: _reachable!);
    _platform = null;
    _reachable = null;
    return result;
  }
}
