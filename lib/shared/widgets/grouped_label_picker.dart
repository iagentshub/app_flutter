import 'package:flutter/material.dart';

import '../labels/label_catalog.dart';

/// Selector de labels organizado por grupo excluyente (visibilidad, entorno)
/// y no excluyente (estado), igual que GROUPS en frontend_vanilla — evita
/// que se puedan marcar a la vez dos labels que son mutuamente excluyentes
/// (p. ej. "private" y "public").
class GroupedLabelPicker extends StatelessWidget {
  const GroupedLabelPicker({
    required this.selected,
    required this.onChanged,
    required this.tx,
    super.key,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final String Function(String path, String fallback) tx;

  void _toggle(LabelGroupDef group, String key, bool value) {
    final next = {...selected};
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
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final group in kLabelGroups) ...[
          Text(tx(group.titleKey, group.fallbackTitle), style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: group.keys.map((key) {
              final isSelected = selected.contains(key);
              final color = labelColor(key);
              return ChoiceChip(
                label: Text(key),
                selected: isSelected,
                onSelected: (value) => _toggle(group, key, value),
                selectedColor: color.withValues(alpha: 0.9),
                labelStyle: TextStyle(color: isSelected ? Colors.white : null, fontWeight: isSelected ? FontWeight.w700 : null),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
