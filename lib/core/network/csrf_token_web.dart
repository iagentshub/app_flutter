import 'package:web/web.dart' as web;

/// En web manda el navegador: la cookie está ahí y se lee en cada petición,
/// así que no hay nada que recordar. Guardar una copia sería peor —quedaría
/// rancia cuando el backend reemite `ga_csrf` tras un cambio de grupo o una
/// impersonación, y el usuario vería 403 hasta recargar.
String? readCsrfToken() {
  final match = RegExp(
    r'(?:^|;\s*)ga_csrf=([^;]*)',
  ).firstMatch(web.document.cookie);
  if (match == null) return null;
  final valor = match.group(1);
  return (valor == null || valor.isEmpty) ? null : Uri.decodeComponent(valor);
}

void rememberCsrfToken(String? value) {}

void forgetCsrfToken() {}
