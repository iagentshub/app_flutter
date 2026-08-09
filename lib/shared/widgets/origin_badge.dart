import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';

/// Chip de propiedad del recurso: propietario, enlace de solo lectura o fork
/// editable. Usa el mismo estilo visual que un label-chip.
class OriginBadge extends StatelessWidget {
  const OriginBadge({
    required this.propertyType,
    required this.ownerLabel,
    required this.linkedLabel,
    required this.forkLabel,
    super.key,
  });

  final String propertyType;
  final String ownerLabel;
  final String linkedLabel;
  final String forkLabel;

  @override
  Widget build(BuildContext context) {
    final (color, text) = switch (propertyType) {
      'fork' => (FncColors.labelFork, forkLabel),
      'linked' => (FncColors.labelLinked, linkedLabel),
      _ => (FncColors.labelOwner, ownerLabel),
    };
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
