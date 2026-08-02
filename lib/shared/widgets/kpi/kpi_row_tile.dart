import 'package:flutter/material.dart';

import 'kpi_common.dart';

/// Tarjeta KPI horizontal: insignia a la izquierda, valor + etiqueta a la
/// derecha. Pensada para grids de altura fija (celdas compactas) donde el
/// layout vertical de [KpiTile] no cabe. Táctil si se pasa [onTap].
class KpiRowTile extends StatelessWidget {
  const KpiRowTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.onTap,
    super.key,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return kpiCardChrome(
      onTap: onTap,
      child: Row(
        children: [
          kpiIconBadge(icon: icon, tint: tint),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
