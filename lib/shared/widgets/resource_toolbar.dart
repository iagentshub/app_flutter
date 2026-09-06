import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

/// Composición uniforme para búsquedas, acciones y resumen de colecciones.
///
/// Las acciones van sobre una superficie con borde, y no sueltas sobre el
/// fondo de la página: sin ella los botones de icono quedaban como círculos
/// flotando sobre el negro y el resumen como una línea de texto suelta debajo,
/// sin nada que los relacionara entre sí ni con la colección que gobiernan.
///
/// El resumen va **dentro del mismo `Wrap`** que las acciones. Estaba en una
/// fila propia, y como siempre es un contador corto —«Workflows: 0»— gastaba
/// un renglón entero para tres palabras. En el `Wrap` acompaña a los botones
/// cuando cabe y baja solo cuando no, sin que nadie mida el ancho.
class ResourceToolbar extends StatelessWidget {
  const ResourceToolbar({
    required this.actions,
    this.search,
    this.summary,
    this.actionSpacing = 6,
    this.sectionSpacing = 12,
    super.key,
  });

  final Widget? search;
  final List<Widget> actions;
  final Widget? summary;
  final double actionSpacing;
  final double sectionSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: FncColors.surfaceMuted(context),
        border: Border.all(color: FncColors.borderSubtle(context)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Se usa el ancho local: una barra dentro de una tarjeta no dispone
          // de todo el viewport. El texto ampliado necesita volver a apilar.
          final inline =
              kIsWeb &&
              constraints.maxWidth /
                      MediaQuery.textScalerOf(context).scale(1) >=
                  760;
          if (kIsWeb && search != null) {
            final searchWidth = inline
                ? (constraints.maxWidth * 0.4).clamp(260.0, 420.0)
                : constraints.maxWidth;
            // La búsqueda permanece en la misma rama al redimensionar, para
            // conservar el texto, la selección y el foco del campo.
            return Wrap(
              spacing: sectionSpacing,
              runSpacing: sectionSpacing,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(width: searchWidth, child: search),
                SizedBox(
                  width: inline
                      ? constraints.maxWidth - searchWidth - sectionSpacing
                      : constraints.maxWidth,
                  child: _actionGroup(context, trailing: inline),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (search != null) ...[
                search!,
                SizedBox(height: sectionSpacing),
              ],
              _actionGroup(context),
            ],
          );
        },
      ),
    );
  }

  Widget _actionGroup(BuildContext context, {bool trailing = false}) => Wrap(
    alignment: trailing ? WrapAlignment.end : WrapAlignment.start,
    spacing: actionSpacing,
    runSpacing: actionSpacing,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      ...actions,
      if (summary != null)
        Padding(
          // Separa el contador del último botón lo justo para que no se
          // lea como uno más de la fila.
          padding: EdgeInsets.only(
            left: (sectionSpacing - actionSpacing).clamp(0.0, double.infinity),
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: FncColors.textMuted(context)),
            child: summary!,
          ),
        ),
    ],
  );
}
