import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';

/// Botón de acción secundaria solo-icono (editar, eliminar, renombrar...),
/// Botón de acción compacto: 34x34, radius 10,
/// sin fondo hasta el hover, y una variante `danger` para acciones
/// destructivas (eliminar).
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = danger
        ? FncColors.materialRed.shade400
        : scheme.onSurfaceVariant;
    final color = onPressed == null
        ? baseColor.withValues(alpha: 0.35)
        : baseColor;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: FncColors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed,
          hoverColor: scheme.surfaceContainerHighest,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}
