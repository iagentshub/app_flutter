import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';

/// Botón de acción secundaria solo-icono (editar, eliminar, renombrar...),
/// Botón de acción compacto: 34x34, radius 10,
/// sin fondo hasta el hover, y una variante `danger` para acciones
/// destructivas (eliminar).
///
/// Lo que se ve mide 34x34, pero el blanco táctil es de 48x48 —el mínimo que
/// piden Material y la WCAG 2.5.5—: el relleno extra lo aporta
/// `MaterialTapTargetSize.padded` y es transparente, así que el aspecto no
/// cambia y el dedo deja de fallar el botón en móvil.
class ActionIconButton extends StatelessWidget {
  const ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.danger = false,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;

  /// Lo que ocupa el botón a la vista (y el área que se ilumina al pasar por
  /// encima). El blanco táctil es mayor, ver [visualSize] vs 48.
  static const double visualSize = 34;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = danger
        ? FncColors.materialRed.shade400
        : scheme.onSurfaceVariant;

    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
        width: visualSize,
        height: visualSize,
      ),
      style: IconButton.styleFrom(
        foregroundColor: baseColor,
        disabledForegroundColor: baseColor.withValues(alpha: 0.35),
        hoverColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(visualSize, visualSize),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}
