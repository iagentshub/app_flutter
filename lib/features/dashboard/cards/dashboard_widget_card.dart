import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

/// Presentación común de una card del dashboard.
///
/// La página decide qué datos mostrar; este componente concentra el aspecto,
/// el modo edición y las acciones para evitar duplicar estructura visual.
class DashboardWidgetCard extends StatelessWidget {
  const DashboardWidgetCard({
    required this.instanceId,
    required this.title,
    required this.body,
    required this.editing,
    required this.reorderIndex,
    required this.inGrid,
    required this.canConfigure,
    required this.configureTooltip,
    required this.removeTooltip,
    required this.onConfigure,
    required this.onRemove,
    super.key,
  });

  final String instanceId;
  final String title;
  final Widget body;
  final bool editing;
  final int reorderIndex;
  final bool inGrid;
  final bool canConfigure;
  final String configureTooltip;
  final String removeTooltip;
  final VoidCallback onConfigure;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey(instanceId),
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (editing)
                  ReorderableDragStartListener(
                    index: reorderIndex,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: FncFonts.size16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (editing && canConfigure)
                  AppIconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: configureTooltip,
                    onPressed: onConfigure,
                  ),
                if (editing)
                  AppIconButton(
                    icon: const Icon(Icons.close),
                    tooltip: removeTooltip,
                    onPressed: onRemove,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            body,
          ],
        ),
      ),
    );
  }
}
