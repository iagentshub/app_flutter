import 'package:flutter/material.dart';

import 'responsive_dialog.dart';

/// Botón de filtros: solo icono + insignia con el nº de filtros activos
/// (el tooltip lleva el texto). Mismo icono/forma en toda la app para que
/// sea reconocible de un vistazo. En rojo si hay algún filtro activo, en
/// gris si no hay ninguno.
class FilterButton extends StatelessWidget {
  const FilterButton({
    required this.activeCount,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final int activeCount;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = activeCount > 0;
    final color = active ? scheme.error : scheme.onSurfaceVariant;
    final button = IconButton.outlined(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(Icons.filter_list, size: 18, color: color),
      style: IconButton.styleFrom(
        side: BorderSide(color: active ? scheme.error : scheme.outline),
      ),
    );
    if (!active) return button;
    return Badge(
      label: Text('$activeCount'),
      backgroundColor: scheme.error,
      alignment: AlignmentDirectional.topEnd,
      offset: const Offset(4, -4),
      child: button,
    );
  }
}

/// Dropdown de filtro reutilizable dentro de un diálogo de [showFilterDialog]:
/// mismo estilo en toda la app para no repetir el widget en cada página.
class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: options
          .map(
            (opt) => DropdownMenuItem(
              value: opt.$1,
              child: Text(opt.$2, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }
}

/// Diálogo de filtros: agrupa los controles secundarios (dropdowns, etc.)
/// que antes iban sueltos en la barra superior. `buildFields` recibe
/// `setDialogState` para que los controles reflejen el cambio al instante
/// dentro del propio diálogo, aunque el estado real viva en la página padre.
Future<void> showFilterDialog(
  BuildContext context, {
  required String title,
  required List<Widget> Function(StateSetter setDialogState) buildFields,
  VoidCallback? onClear,
  VoidCallback? onApply,
  String clearLabel = 'Limpiar filtros',
  String closeLabel = 'Cerrar',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: dialogContentWidth(context, 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: buildFields(setDialogState),
            ),
          ),
        ),
        actions: [
          if (onClear != null)
            TextButton(
              onPressed: () {
                onClear();
                setDialogState(() {});
              },
              child: Text(clearLabel),
            ),
          FilledButton(
            onPressed: () {
              onApply?.call();
              Navigator.of(context).pop();
            },
            child: Text(closeLabel),
          ),
        ],
      ),
    ),
  );
}
