import 'package:flutter/material.dart';

/// Fila de chips tipo pill para un filtro categórico de pocas opciones,
/// equivalente a `.fco-chip`/`.fa-chip` en frontend_vanilla.
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<(String value, String label)> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final selected = opt.$1 == value;
        return ChoiceChip(
          label: Text(opt.$2),
          selected: selected,
          onSelected: (_) => onChanged(opt.$1),
        );
      }).toList(),
    );
  }
}
