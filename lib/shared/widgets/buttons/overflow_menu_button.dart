import 'package:flutter/material.dart';

/// Una acción del menú «⋮» de una tarjeta.
class OverflowMenuAction {
  const OverflowMenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.danger = false,
    this.enabled = true,
    this.separatedBefore = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;

  /// Acción irreversible (eliminar): se pinta en el color de error y va
  /// separada del resto para que no se pulse por inercia.
  final bool danger;

  /// Disponible para este recurso. Un recurso compartido de solo lectura, por
  /// ejemplo, no se puede volver a compartir.
  final bool enabled;

  /// Precede la acción con un separador.
  final bool separatedBefore;
}

/// Menú de acciones secundarias de una tarjeta de recurso.
///
/// Las filas de acciones de las tarjetas crecían hasta desbordar a ancho de
/// móvil —`AgentCard` llegó a los ocho botones y sacaba 70 px fuera, con
/// eliminar entre lo que quedaba sin poder pulsarse—. Con este menú solo se
/// quedan a la vista la acción principal y la de editar; el resto vive aquí,
/// que ocupa siempre lo mismo por muchas acciones que se añadan.
class OverflowMenuButton extends StatelessWidget {
  const OverflowMenuButton({
    required this.actions,
    required this.tooltip,
    super.key,
  });

  final List<OverflowMenuAction> actions;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<int>(
      tooltip: tooltip,
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (index) => actions[index].onSelected(),
      itemBuilder: (context) {
        final items = <PopupMenuEntry<int>>[];
        for (var index = 0; index < actions.length; index++) {
          final action = actions[index];
          if (action.separatedBefore && items.isNotEmpty) {
            items.add(const PopupMenuDivider());
          }
          final color = !action.enabled
              ? theme.disabledColor
              : action.danger
              ? theme.colorScheme.error
              : null;
          items.add(
            PopupMenuItem<int>(
              value: index,
              enabled: action.enabled,
              child: Row(
                children: [
                  Icon(action.icon, size: 18, color: color),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(action.label, style: TextStyle(color: color)),
                  ),
                ],
              ),
            ),
          );
        }
        return items;
      },
    );
  }
}
