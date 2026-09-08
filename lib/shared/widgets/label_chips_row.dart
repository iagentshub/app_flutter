import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';
import '../labels/label_catalog.dart';

/// Etiquetas neutras; el punto conserva el color de cada categoría.
/// [leading] permite insertar otros chips (p. ej. OriginBadge) en la misma
/// fila, igual que el originChip que va junto a los label-chips en web.
class LabelChipsRow extends StatelessWidget {
  const LabelChipsRow({
    required this.labels,
    this.hide = const [],
    this.leading = const [],
    this.labelText,
    super.key,
  });

  final List<String> labels;
  final List<String> hide;
  final List<Widget> leading;
  final String Function(String label)? labelText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = labels.where((l) => !hide.contains(l)).toList();
    if (visible.isEmpty && leading.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...leading,
        ...visible.map((label) {
          final color = labelColor(label);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: FncColors.statusColor(
                      color,
                      scheme.surfaceContainer,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  labelText?.call(label) ?? label,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: FncFonts.size12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
