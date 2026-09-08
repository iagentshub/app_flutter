import 'package:flutter/material.dart';

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
    final scheme = Theme.of(context).colorScheme;
    final text = switch (propertyType) {
      'fork' => forkLabel,
      'linked' => linkedLabel,
      _ => ownerLabel,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: FncFonts.size12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
