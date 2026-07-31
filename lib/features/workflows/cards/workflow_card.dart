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
    final metadata = [
      '${item.nodes.length} $stepsLabel',
      '${item.edges.length} $connectionsLabel',
    ];

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(metadata.join(' · ')),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
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
            const SizedBox(height: 10),
            Row(
              children: [
                SecondaryButton.icon(
                  onPressed: onRun,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text(runLabel),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: editTooltip,
                  onPressed: onEdit,
                ),
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
