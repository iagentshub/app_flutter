/// Formato de fechas sin dependencia de `intl`.
///
/// El backend devuelve ISO-8601 con segundos, microsegundos y zona
/// (`2026-08-25T09:41:03.512874+00:00`) y esa cadena llegó a pintarse cruda en
/// la ficha de perfil: veinte y pico caracteres donde el usuario solo quiere
/// saber el día. Aquí se recorta a lo que se lee de un vistazo y se pasa a
/// hora local, que es la otra mitad del problema —el backend guarda en UTC.
///
/// El mismo bloque de cuatro líneas estaba copiado en `admin_page.dart`,
/// `active_sessions_dialog.dart` y `resource_history_dialog.dart`; este es el
/// sitio al que deben ir migrando.
library;

String _dos(int valor) => valor.toString().padLeft(2, '0');

/// `dd/MM/yyyy HH:mm` en hora local. Devuelve [siNoHay] si no hay fecha y la
/// cadena original si no se puede interpretar —perder el dato por no saber
/// leerlo sería peor que enseñarlo feo.
String formatDateTimeShort(String? iso, {String siNoHay = '—'}) {
  if (iso == null || iso.isEmpty) return siNoHay;
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  return '${_dos(local.day)}/${_dos(local.month)}/${local.year} '
      '${_dos(local.hour)}:${_dos(local.minute)}';
}

/// `dd/MM/yyyy` en hora local, para cuando la hora no aporta nada.
String formatDateShort(String? iso, {String siNoHay = '—'}) {
  if (iso == null || iso.isEmpty) return siNoHay;
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final local = parsed.toLocal();
  return '${_dos(local.day)}/${_dos(local.month)}/${local.year}';
}
