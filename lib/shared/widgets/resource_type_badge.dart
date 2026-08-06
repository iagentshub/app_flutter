import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';
import '../labels/label_catalog.dart';

/// Chip de tipo de recurso coloreado según `labelColor` del catálogo de
/// etiquetas (grupo "Tipo"), para que agente/skill/knowledge/conexión/
/// memoria/orquestación se vean siempre con el mismo color en Explorar,
/// Dashboard, Buscar por etiqueta y el perfil público.
class ResourceTypeBadge extends StatelessWidget {
  const ResourceTypeBadge({required this.type, required this.label, super.key});

  final String type;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: labelColor(type),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
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
