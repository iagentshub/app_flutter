import 'package:flutter/material.dart';

import 'kpi_common.dart';

/// Tarjeta KPI vertical: insignia/anillo arriba, valor grande, etiqueta y
/// (opcional) una línea de contexto tipo "62% del total" debajo.
class KpiTile extends StatelessWidget {
  const KpiTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.progress,
    this.progressLabel,
    super.key,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color tint;

  /// 0.0–1.0. Si no es `null`, la insignia se sustituye por un anillo
  /// [ArcGauge] con este avance.
  final double? progress;

  /// Línea de contexto bajo la etiqueta (p. ej. "62% del total"). Solo tiene
  /// sentido junto a [progress].
  final String? progressLabel;

  @override
  Widget build(BuildContext context) {
    return kpiCardChrome(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          kpiIconBadge(icon: icon, tint: tint, progress: progress),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (progressLabel != null) ...[
            const SizedBox(height: 2),
            Text(
              progressLabel!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
