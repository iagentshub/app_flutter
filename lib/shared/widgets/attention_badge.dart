import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';

/// Chip que marca un recurso utilizable solo a medias y que necesita una
/// acción del usuario — por ejemplo una conexión cuya credencial guardada ya
/// no se puede descifrar. El motivo concreto va en el tooltip: el chip solo
/// tiene sitio para el aviso.
///
/// Mismo estilo que [OriginBadge] e [InactiveBadge], en color de advertencia.
class AttentionBadge extends StatelessWidget {
  const AttentionBadge({required this.label, this.tooltip, super.key});

  final String label;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FncColors.warning,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: FncColors.white,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: FncColors.white,
              fontSize: FncFonts.size10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
    final message = tooltip;
    if (message == null || message.isEmpty) return badge;
    return Tooltip(message: message, child: badge);
  }
}
