import 'package:flutter/material.dart';

import '../labels/label_catalog.dart';

/// Fila de chips de labels de un recurso, igual a `.label-chip` en
/// frontend_vanilla: píldora de color fijo por clave + punto antes del texto.
class LabelChipsRow extends StatelessWidget {
  const LabelChipsRow({required this.labels, this.hide = const [], super.key});

  final List<String> labels;
  final List<String> hide;

  @override
  Widget build(BuildContext context) {
    final visible = labels.where((l) => !hide.contains(l)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: visible.map((label) {
        final color = labelColor(label);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.7), shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
