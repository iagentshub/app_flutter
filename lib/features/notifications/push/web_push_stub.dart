/// Implementación para las plataformas que no son web.
///
/// Devuelve «no soportado» en vez de lanzar: quien pregunta es la pantalla de
/// ajustes, y lo que necesita saber es si enseñar el interruptor.
class WebPush {
  const WebPush();

  /// El navegador soporta push. Fuera de web, no.
  bool get soportado => false;

  /// Permiso concedido por el usuario.
  bool get concedido => false;

  Future<PushEstado> estado() async => PushEstado.noSoportado;

  Future<PushEstado> activar(String clavePublicaVapid) async =>
      PushEstado.noSoportado;

  Future<String?> desactivar() async => null;

  /// Los datos que el backend necesita para cifrar hacia este navegador.
  Future<Map<String, String>?> datosDeSuscripcion() async => null;

  /// En iPhone hay que instalar la aplicación antes de poder recibir push.
  bool get requiereInstalarEnIOS => false;
}

/// En qué punto está el permiso de este navegador.
enum PushEstado {
  /// El navegador no sabe hacer push, o la app no corre en uno.
  noSoportado,

  /// Se puede pedir el permiso: nadie lo ha decidido todavía.
  disponible,

  /// Activo y suscrito.
  activo,

  /// El usuario dijo que no. **No se puede volver a preguntar**: el navegador
  /// solo lo permite si lo cambia él a mano desde el candado de la barra.
  denegado,
}
