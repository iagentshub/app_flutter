import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';

/// Atenúa el contenido de una tarjeta desactivada.
///
/// Las tarjetas terminaban en `Opacity(opacity: 0.6, child: card)`. `Opacity`
/// con un valor intermedio obliga a Flutter a un `saveLayer`: renderiza el
/// subárbol en una textura aparte y luego la compone. En una rejilla con
/// varios recursos desactivados son varias capas fuera de pantalla por frame,
/// justo en la vista que además se desplaza. Bajar la intensidad de los
/// colores heredados da el mismo efecto sin capa nueva, que es lo que
/// recomienda la propia documentación de `Opacity`.
///
/// Lo que lleva color propio —el badge de «Inactivo», el botón de acción
/// principal— conserva su intensidad, y así sigue leyéndose y pulsándose.
Widget dimmedWhenInactive(BuildContext context, Widget child) {
  const factor = 0.6;
  final scheme = Theme.of(context).colorScheme;
  final textStyle = DefaultTextStyle.of(context).style;
  final iconTheme = IconTheme.of(context);
  Color atenuado(Color? color) =>
      (color ?? scheme.onSurface).withValues(alpha: factor);

  return DefaultTextStyle(
    style: textStyle.copyWith(color: atenuado(textStyle.color)),
    child: IconTheme(
      data: iconTheme.copyWith(color: atenuado(iconTheme.color)),
      child: child,
    ),
  );
}

/// Chip que marca un recurso desactivado (borrado suave). Se muestra solo
/// cuando `is_active == false`; sigue el mismo estilo que [OriginBadge].
class InactiveBadge extends StatelessWidget {
  const InactiveBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FncColors.gray6B7280,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FncColors.white,
          fontSize: FncFonts.size10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
