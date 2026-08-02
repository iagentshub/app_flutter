import 'package:flutter/material.dart';

import 'arc_gauge.dart';

/// Un anillo secundario dentro de [KpiHeroCard] (p. ej. "Activos: 62%").
class KpiHeroRing {
  const KpiHeroRing({
    required this.progress,
    required this.label,
    required this.color,
  });

  /// 0.0–1.0.
  final double progress;
  final String label;
  final Color color;
}

/// Tarjeta KPI protagonista: un valor grande a la izquierda (o arriba, en
/// viewports estrechos) junto con una fila de anillos [ArcGauge] compactos
/// que dan contexto sin necesitar tarjetas propias — p. ej. el total de
/// usuarios junto con el % de activos/verificados sobre ese total.
class KpiHeroCard extends StatelessWidget {
  const KpiHeroCard({
    required this.title,
    required this.value,
    required this.rings,
    this.narrowBreakpoint = 360,
    super.key,
  });

  final String title;
  final int value;
  final List<KpiHeroRing> rings;

  /// Ancho por debajo del cual el valor y los anillos se apilan en vertical
  /// en vez de compartir una fila.
  final double narrowBreakpoint;

  @override
  Widget build(BuildContext context) {
    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w800,
            height: 1.0,
          ),
        ),
      ],
    );

    final ringsRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rings.length; i++) ...[
          if (i > 0) const SizedBox(width: 20),
          _ring(context, rings[i]),
        ],
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < narrowBreakpoint) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [headline, const SizedBox(height: 18), ringsRow],
              );
            }
            return Row(
              children: [
                Expanded(child: headline),
                ringsRow,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _ring(BuildContext context, KpiHeroRing ring) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ArcGauge(
          progress: ring.progress,
          color: ring.color,
          size: 56,
          strokeWidth: 5,
          child: Text(
            '${(ring.progress * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ring.color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(ring.label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
