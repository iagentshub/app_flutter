/// Alta y baja de las notificaciones push del navegador.
///
/// Solo existe de verdad en web. En Android e iOS nativos el push no pasa por
/// aquí sino por FCM y APNs, que necesitan las aplicaciones publicadas en las
/// tiendas; hasta entonces el stub deja la función desactivada y la interfaz
/// no ofrece el interruptor.
library;

export 'web_push_stub.dart' if (dart.library.js_interop) 'web_push_web.dart';
