/// El origen de la página, para explicar por qué el navegador tira la sesión.
///
/// Las cookies de sesión son `SameSite=Lax`: viajan entre puertos del mismo
/// host, pero no entre sitios distintos. Y `127.0.0.1` es un sitio **distinto**
/// de `localhost` aunque sean la misma máquina, que es justo el punto donde
/// esto se vuelve indistinguible sin ver los dos valores juntos.
library;

export 'page_origin_stub.dart'
    if (dart.library.js_interop) 'page_origin_web.dart';
