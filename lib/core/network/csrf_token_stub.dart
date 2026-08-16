/// Fuera de web no hay cookie jar: el token se guarda en memoria.
String? _token;

String? readCsrfToken() => _token;

/// Guarda el token visto en un `set-cookie`. `null` no borra: el backend solo
/// manda la cookie cuando cambia, así que la mayoría de respuestas no la traen.
void rememberCsrfToken(String? value) {
  if (value != null && value.isNotEmpty) _token = value;
}

void forgetCsrfToken() => _token = null;
