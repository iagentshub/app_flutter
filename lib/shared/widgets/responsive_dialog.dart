import 'package:flutter/material.dart';

/// Ancho a usar en el `content` de un `AlertDialog`/`Dialog`: el preferido en
/// pantallas anchas, pero nunca más que el ancho disponible menos un margen
/// — evita que un `SizedBox(width: N)` fijo desborde en un móvil estrecho.
double dialogContentWidth(
  BuildContext context,
  double preferredWidth, {
  double margin = 48,
}) {
  final available = MediaQuery.sizeOf(context).width - margin;
  return preferredWidth < available ? preferredWidth : available;
}

/// Igual que [dialogContentWidth] pero para el alto — evita que un
/// `SizedBox(height: N)` fijo recorte contenido en una pantalla baja
/// (móvil en horizontal, ventana de escritorio pequeña).
double dialogContentHeight(
  BuildContext context,
  double preferredHeight, {
  double margin = 120,
}) {
  final available = MediaQuery.sizeOf(context).height - margin;
  return preferredHeight < available ? preferredHeight : available;
}
