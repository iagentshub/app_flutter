import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/workflows/workflow_models.dart';
import '../../../shared/graph/resource_graph_builder.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_graph_button.dart';

class WorkflowCard extends StatelessWidget {
  const WorkflowCard({
    required this.item,
    required this.agentsById,
    this.graphNamesLoader,
    required this.stepsLabel,
    required this.connectionsLabel,
    required this.ownerLabel,
    required this.linkedLabel,
    required this.forkLabel,
    required this.labelText,
    required this.runLabel,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.graphTooltip,
    required this.graphCloseLabel,
    required this.graphEmptyLabel,
    required this.graphSearchHint,
    required this.graphSortTooltip,
    required this.graphSortHierarchyVerticalLabel,
    required this.graphSortHierarchyHorizontalLabel,
    required this.graphSortGalaxyLabel,
    required this.graphShowLabelsTooltip,
    required this.graphHideLabelsTooltip,
    required this.graphQuickViewDescriptionLabel,
    required this.graphQuickViewNoDescriptionLabel,
    required this.graphQuickViewConnectionsLabel,
    required this.graphQuickViewNoConnectionsLabel,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
    this.inProgress = false,
    this.inProgressLabel = 'En curso',
    this.inactiveLabel = 'Desactivado',
    this.activateTooltip = 'Activar',
    this.deactivateTooltip = 'Desactivar',
    this.onToggleActive,
    super.key,
  });

  final WorkflowItem item;

  /// Agentes completos indexados por id, usados para expandir cada paso del
  /// grafo con las skills/knowledge/conexión/memoria del agente al que
  /// apunta (mismo detalle que el grafo de una card de agente individual).
  final Map<String, AgentItem> agentsById;

  /// Nombres legibles de skills, prompts, tools, knowledge, packs y
  /// conexiones, cargados al abrir el grafo. Sin ellos cada nodo se
  /// etiquetaba con el id crudo, que es lo que hacía que el grafo del mismo
  /// agente se viera distinto abierto desde aquí o desde Agentes.
  final Future<ResourceNames> Function()? graphNamesLoader;
  final String stepsLabel;
  final String connectionsLabel;
  final String ownerLabel;
  final String linkedLabel;
  final String forkLabel;
  final String Function(String label) labelText;
  final String runLabel;
  final String editTooltip;
  final String deleteTooltip;
  final String graphTooltip;
  final String graphCloseLabel;
  final String graphEmptyLabel;
  final String graphSearchHint;
  final String graphSortTooltip;
  final String graphSortHierarchyVerticalLabel;
  final String graphSortHierarchyHorizontalLabel;
  final String graphSortGalaxyLabel;
  final String graphShowLabelsTooltip;
  final String graphHideLabelsTooltip;
  final String graphQuickViewDescriptionLabel;
  final String graphQuickViewNoDescriptionLabel;
  final String graphQuickViewConnectionsLabel;
  final String graphQuickViewNoConnectionsLabel;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool inProgress;
  final String inProgressLabel;
  final String inactiveLabel;
  final String activateTooltip;
  final String deactivateTooltip;

  /// Activar/desactivar (borrado suave). Null = acción no disponible.
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                if (!item.isActive) ...[
                  const SizedBox(width: 8),
                  InactiveBadge(label: inactiveLabel),
                ],
                if (inProgress) ...[
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const SizedBox.square(
                      dimension: 14,
                      child: IAgentsLoadingMark(),
                    ),
                    label: Text(inProgressLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _WorkflowMetric(
                  icon: Icons.smart_toy_outlined,
                  value: item.nodes.length,
                  label: stepsLabel,
                ),
                _WorkflowMetric(
                  icon: Icons.arrow_forward_rounded,
                  value: item.edges.length,
                  label: connectionsLabel,
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: colors.onSurfaceVariant, height: 1.35),
              ),
            ],
            const SizedBox(height: 14),
            LabelChipsRow(
              labels: item.displayLabels,
              labelText: labelText,
              leading: [
                OriginBadge(
                  propertyType: item.propertyType,
                  ownerLabel: ownerLabel,
                  linkedLabel: linkedLabel,
                  forkLabel: forkLabel,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                PrimaryButton.icon(
                  onPressed: !item.isActive || inProgress ? null : onRun,
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 16),
                  label: Text(
                    runLabel,
                    style: const TextStyle(fontSize: FncFonts.size12),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 8),
                ResourceGraphButton(
                  tooltip: graphTooltip,
                  dialogTitle: item.name,
                  buildGraph: () async => workflowGraph(
                    workflow: item,
                    agentsById: agentsById,
                    names:
                        await graphNamesLoader?.call() ?? const ResourceNames(),
                  ),
                  closeLabel: graphCloseLabel,
                  searchHint: graphSearchHint,
                  sortTooltip: graphSortTooltip,
                  sortHierarchyVerticalLabel: graphSortHierarchyVerticalLabel,
                  sortHierarchyHorizontalLabel:
                      graphSortHierarchyHorizontalLabel,
                  sortGalaxyLabel: graphSortGalaxyLabel,
                  showLabelsTooltip: graphShowLabelsTooltip,
                  hideLabelsTooltip: graphHideLabelsTooltip,
                  quickViewDescriptionLabel: graphQuickViewDescriptionLabel,
                  quickViewNoDescriptionLabel: graphQuickViewNoDescriptionLabel,
                  quickViewConnectionsLabel: graphQuickViewConnectionsLabel,
                  quickViewNoConnectionsLabel: graphQuickViewNoConnectionsLabel,
                  emptyLabel: graphEmptyLabel,
                ),
                const SizedBox(width: 8),
                if (onToggleActive != null) ...[
                  ActionIconButton(
                    icon: item.isActive
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                    tooltip: item.isActive
                        ? deactivateTooltip
                        : activateTooltip,
                    onPressed: onToggleActive,
                  ),
                  const SizedBox(width: 8),
                ],
                if (!item.readOnly) ...[
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: editTooltip,
                    onPressed: onEdit,
                  ),
                  const SizedBox(width: 4),
                  ActionIconButton(
                    icon: Icons.delete_outline,
                    tooltip: deleteTooltip,
                    danger: true,
                    onPressed: onDelete,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );

    if (item.isActive) return card;
    return dimmedWhenInactive(context, card);
  }
}

class _WorkflowMetric extends StatelessWidget {
  const _WorkflowMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            '$value $label',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
