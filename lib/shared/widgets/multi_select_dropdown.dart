import 'package:flutter/material.dart';

class MultiSelectDropdownOption<T> {
  const MultiSelectDropdownOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.count,
    this.groupLabel,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final int? count;
  final String? groupLabel;
}

typedef MultiSelectReducer<T> =
    Set<T> Function(Set<T> current, T value, bool selected);

/// Selector compacto inspirado en el filtro de tipos de Admin.
///
/// Mantiene el menú abierto para poder marcar varias opciones y admite
/// encabezados de grupo, iconos, colores y un reductor personalizado para
/// reglas como grupos exclusivos o selecciones obligatorias.
class MultiSelectDropdown<T> extends StatelessWidget {
  const MultiSelectDropdown({
    required this.options,
    required this.selectedValues,
    required this.emptyLabel,
    required this.tooltip,
    required this.onChanged,
    this.labelText,
    this.multipleSelectedLabel,
    this.selectionReducer,
    this.allowEmpty = true,
    this.width,
    super.key,
  });

  final List<MultiSelectDropdownOption<T>> options;
  final Set<T> selectedValues;
  final String emptyLabel;
  final String tooltip;
  final ValueChanged<Set<T>> onChanged;
  final String? labelText;
  final String Function(int count)? multipleSelectedLabel;
  final MultiSelectReducer<T>? selectionReducer;
  final bool allowEmpty;
  final double? width;

  String get _selectionLabel {
    if (selectedValues.isEmpty) return emptyLabel;
    if (selectedValues.length > 1) {
      return multipleSelectedLabel?.call(selectedValues.length) ??
          '${selectedValues.length}';
    }
    final selected = options
        .where((option) => selectedValues.contains(option.value))
        .firstOrNull;
    return selected?.label ?? emptyLabel;
  }

  String _optionLabel(MultiSelectDropdownOption<T> option) =>
      option.count == null ? option.label : '${option.label} (${option.count})';

  Set<T> _defaultReduce(Set<T> current, T value, bool selected) {
    final next = Set<T>.of(current);
    if (selected) {
      next.add(value);
    } else {
      next.remove(value);
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: width,
      child: PopupMenuButton<void>(
        tooltip: tooltip,
        position: PopupMenuPosition.under,
        itemBuilder: (context) {
          var menuSelection = Set<T>.of(selectedValues);
          return [
            PopupMenuItem<void>(
              enabled: false,
              padding: EdgeInsets.zero,
              child: StatefulBuilder(
                builder: (context, setMenuState) => SizedBox(
                  width: 280,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (allowEmpty) ...[
                        CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: menuSelection.isEmpty,
                          title: Text(emptyLabel),
                          onChanged: (_) {
                            setMenuState(() => menuSelection = <T>{});
                            onChanged(<T>{});
                          },
                        ),
                        const Divider(height: 1),
                      ],
                      for (var index = 0; index < options.length; index++) ...[
                        if (options[index].groupLabel != null &&
                            (index == 0 ||
                                options[index - 1].groupLabel !=
                                    options[index].groupLabel))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              options[index].groupLabel!,
                              style: Theme.of(context).textTheme.labelMedium,
                            ),
                          ),
                        CheckboxListTile(
                          dense: true,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: menuSelection.contains(options[index].value),
                          secondary: options[index].icon != null
                              ? Icon(
                                  options[index].icon,
                                  size: 18,
                                  color: options[index].color,
                                )
                              : options[index].color != null
                              ? Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: options[index].color,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              : null,
                          title: Text(_optionLabel(options[index])),
                          onChanged: (checked) {
                            final reducer = selectionReducer ?? _defaultReduce;
                            setMenuState(() {
                              menuSelection = reducer(
                                menuSelection,
                                options[index].value,
                                checked == true,
                              );
                            });
                            onChanged(Set<T>.of(menuSelection));
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: labelText,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            border: const OutlineInputBorder(),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _selectionLabel,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
