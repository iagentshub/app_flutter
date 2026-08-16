/// Token anti-CSRF de la sesión, resuelto según la plataforma.
///
/// El backend lo emite en la cookie `ga_csrf` —sin `HttpOnly` justamente para
/// que el cliente pueda reenviarlo— y lo exige en la cabecera `X-CSRF-Token`
/// en todo método con efectos. Es la segunda capa sobre `SameSite=Lax`, que
/// no cubre un subdominio comprometido porque para el navegador es «el mismo
/// sitio».
///
/// En web la cookie la gestiona el navegador y se lee de `document.cookie`.
/// Fuera de web no hay jar: la sesión se manda a mano, así que el token se
/// captura del `set-cookie` de cada respuesta y se guarda en memoria.
library;

export 'csrf_token_stub.dart'
    if (dart.library.js_interop) 'csrf_token_web.dart';
