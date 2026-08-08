import 'package:flutter/material.dart';

import '../labels/label_catalog.dart';
import 'multi_select_dropdown.dart';

/// Selector de labels organizado por grupo excluyente (visibilidad, entorno)
/// y no excluyente (estado); evita
/// que se puedan marcar a la vez dos labels que son mutuamente excluyentes
/// (p. ej. "private" y "public").
class GroupedLabelPicker extends StatelessWidget {
  const GroupedLabelPicker({
    required this.selected,
    required this.onChanged,
    required this.tx,
    this.groups = kLabelGroups,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String Function(String path, String fallback) tx;
  final List<LabelGroupDef> groups;

  Set<String> _reduce(Set<String> current, String key, bool value) {
    final next = {...current};
    final group = groups.firstWhere(
      (candidate) => candidate.keys.contains(key),
    );
    if (group.exclusive) {
      next.removeWhere(group.keys.contains);
      if (value) {
        next.add(key);
      } else if (group.required) {
        next.add(group.keys.first);
      }
    } else {
      if (value) {
        next.add(key);
      } else {
        next.remove(key);
      }
    }
    return next;
  }

  @override
  Widget build(BuildContext context) {
    final allowedKeys = groups.expand((group) => group.keys).toSet();
    final selectedHere = selected.intersection(allowedKeys);
    final outsideSelection = selected.difference(allowedKeys);
    final label = groups.length == 1
        ? tx(groups.first.titleKey, groups.first.fallbackTitle)
        : tx('labels.selector_label', 'Etiquetas');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: MultiSelectDropdown<String>(
        labelText: label,
        tooltip: tx('labels.selector_tooltip', 'Seleccionar etiquetas'),
        emptyLabel: tx('labels.none', 'Ninguna'),
        multipleSelectedLabel: (count) => tx(
          'labels.selected_count',
          '{count} etiquetas seleccionadas',
        ).replaceAll('{count}', '$count'),
        options: [
          for (final group in groups)
            for (final key in group.keys)
              MultiSelectDropdownOption(
                value: key,
                label: tx('labels.$key', key),
                color: labelColor(key),
                groupLabel: groups.length > 1
                    ? tx(group.titleKey, group.fallbackTitle)
                    : null,
              ),
        ],
        selectedValues: selectedHere,
        selectionReducer: _reduce,
        allowEmpty: groups.every((group) => !group.required),
        onChanged: (next) => onChanged({...outsideSelection, ...next}),
      ),
    );
  }
}
