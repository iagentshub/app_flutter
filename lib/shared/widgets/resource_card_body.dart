import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// En las tarjetas el color intenso se reserva para la acción de la página.
ButtonStyle resourceCardActionStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return FilledButton.styleFrom(
    backgroundColor: colors.surfaceContainerHighest,
    foregroundColor: colors.onSurface,
    overlayColor: colors.onSurface,
  ).copyWith(
    side: WidgetStateProperty.resolveWith(
      (states) => BorderSide(
        color: states.contains(WidgetState.focused)
            ? colors.primary
            : Colors.transparent,
        width: 2,
      ),
    ),
  );
}

/// Mantiene el pie de acciones abajo cuando una fila web iguala las alturas.
class ResourceCardBody extends StatelessWidget {
  const ResourceCardBody({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || children.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: children.sublist(0, children.length - 1),
        ),
        children.last,
      ],
    );
  }
}

/// Las acciones web pueden pasar a otra línea al ampliar el texto.
class ResourceCardActions extends StatelessWidget {
  const ResourceCardActions({
    required this.primary,
    required this.actions,
    super.key,
  });

  final Widget primary;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => kIsWeb
      ? Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            primary,
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        )
      : Row(children: [primary, const Spacer(), ...actions]);
}

/// Acciones sin CTA principal: conservan su fila nativa y se ajustan en web.
class ResourceTrailingActions extends StatelessWidget {
  const ResourceTrailingActions({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => kIsWeb
      ? Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 4,
          runSpacing: 4,
          children: children,
        )
      : Row(children: [const Spacer(), ...children]);
}
