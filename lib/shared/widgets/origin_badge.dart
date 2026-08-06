import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';

/// Chip de origen del recurso: si es tuyo directamente ("Propietario") o
/// llegó vía group share ("Enlazado"), igual al originChip de
/// Usa el mismo estilo visual que un label-chip.
class OriginBadge extends StatelessWidget {
  const OriginBadge({
    required this.shared,
    required this.ownerLabel,
    required this.linkedLabel,
    super.key,
  });

  final bool shared;
  final String ownerLabel;
  final String linkedLabel;

  @override
  Widget build(BuildContext context) {
    final color = shared ? FncColors.labelLinked : FncColors.labelOwner;
    final text = shared ? linkedLabel : ownerLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: FncColors.white,
          fontSize: FncFonts.size10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
