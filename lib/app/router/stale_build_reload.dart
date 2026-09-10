/// Recarga la pestaña cuando una parte diferida ya no casa con el bundle.
///
/// dart2js comprueba el hash de cada parte contra el que espera el
/// `main.dart.js` que está corriendo. Las partes se regeneran en cada build
/// con nombres fijos (`main.dart.js_N.part.js`), así que una pestaña abierta
/// desde antes del último despliegue —watchtower actualiza la imagen hasta
/// cada hora sin avisar— descarga partes nuevas para un bundle viejo y las
/// cuatro secciones diferidas fallan a la vez. Reintentar la descarga no lo
/// arregla nunca; solo lo arregla volver a pedir `main.dart.js`.
library;

export 'stale_build_reload_stub.dart'
    if (dart.library.js_interop) 'stale_build_reload_web.dart';
