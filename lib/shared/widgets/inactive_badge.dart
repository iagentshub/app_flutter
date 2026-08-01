import 'package:flutter/material.dart';

/// Chip que marca un recurso desactivado (borrado suave). Se muestra solo
/// cuando `is_active == false`; sigue el mismo estilo que [OriginBadge].
class InactiveBadge extends StatelessWidget {
  const InactiveBadge({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF6B7280),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
