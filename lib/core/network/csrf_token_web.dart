import 'package:web/web.dart' as web;

import '../config/security_contract.dart';

/// En web manda el navegador: la cookie está ahí y se lee en cada petición,
/// así que no hay nada que recordar. Guardar una copia sería peor —quedaría
/// rancia cuando el backend reemite `ga_csrf` tras un cambio de grupo o una
/// impersonación, y el usuario vería 403 hasta recargar.
String? readCsrfToken() {
  return SecurityContract.readCookieValue(
    web.document.cookie,
    SecurityCookieId.csrf,
    decode: true,
  );
}

void rememberCsrfToken(String? value) {}

void forgetCsrfToken() {}
