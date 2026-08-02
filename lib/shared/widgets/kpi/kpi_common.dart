import 'package:flutter/material.dart';

import 'arc_gauge.dart';

/// Insignia de icono de una tarjeta KPI — cuadrada y tintada para un conteo
/// simple, o un anillo [ArcGauge] cuando hay una proporción real que
/// comunicar (activos/verificados sobre un total, etc.). La decisión
/// (badge vs. anillo) la toma [progress]: la comparten [KpiTile] y
/// [KpiRowTile] para no duplicar el criterio en cada uno.
Widget kpiIconBadge({
  required IconData icon,
  required Color tint,
  double? progress,
  double size = 34,
}) {
  if (progress != null) {
    return ArcGauge(
      progress: progress,
      color: tint,
      size: size + 6,
      strokeWidth: 4,
      child: Icon(icon, size: size * 0.47, color: tint),
    );
  }
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: tint.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(size * 0.26),
    ),
    child: Icon(icon, size: size * 0.53, color: tint),
  );
}

/// Card + InkWell táctil opcional compartido por las tarjetas KPI.
Widget kpiCardChrome({
  required Widget child,
  VoidCallback? onTap,
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
}) {
  final content = Padding(padding: padding, child: child);
  return Card(
    margin: EdgeInsets.zero,
    child: onTap == null
        ? content
        : InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: content,
          ),
  );
}
