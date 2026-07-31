import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../models/workflows/workflow_models.dart';

class WorkflowCard extends StatelessWidget {
  const WorkflowCard({
    required this.item,
    required this.stepsLabel,
    required this.connectionsLabel,
    required this.ownerLabel,
    required this.linkedLabel,
    required this.runLabel,
    required this.editTooltip,
    required this.deleteTooltip,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final WorkflowItem item;
  final String stepsLabel;
  final String connectionsLabel;
  final String ownerLabel;
  final String linkedLabel;
  final String runLabel;
  final String editTooltip;
  final String deleteTooltip;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.account_tree_outlined,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: editTooltip,
                  onPressed: onEdit,
                ),
              ],
            ),
            const SizedBox(height: 14),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 14),
            LabelChipsRow(
              labels: item.labels,
              leading: [
                OriginBadge(
                  shared: item.shared,
                  ownerLabel: ownerLabel,
                  linkedLabel: linkedLabel,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton.icon(
                    onPressed: onRun,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: Text(runLabel),
                  ),
                ),
                const SizedBox(width: 8),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: deleteTooltip,
                  danger: true,
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
