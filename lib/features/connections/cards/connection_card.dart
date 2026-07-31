import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../models/connections/connection_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';

typedef ConnectionCardText = String Function(String path, String fallback);

class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    required this.item,
    required this.tx,
    required this.onTest,
    required this.onShare,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final ConnectionItem item;
  final ConnectionCardText tx;
  final VoidCallback onTest;
  final VoidCallback onShare;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final metaParts = <String>[item.type];
    if (item.model.isNotEmpty) metaParts.add(item.model);
    if (item.host.isNotEmpty) metaParts.add(item.host);
    if (item.url.isNotEmpty) metaParts.add(item.url);

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
            Text(metaParts.join(' · ')),
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: [
                ...item.labels,
                if (item.personalKey) 'Personal',
                if (item.isVirtual) 'Virtual',
              ],
              leading: [
                OriginBadge(
                  shared: item.shared,
                  ownerLabel: tx('common.owner', 'Propietario'),
                  linkedLabel: tx('common.linked', 'Enlazado'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                SecondaryButton.icon(
                  onPressed: item.isVirtual ? null : onTest,
                  icon: const Icon(Icons.health_and_safety_outlined),
                  label: Text(tx('connections.test', 'Test')),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: tx('common.share_group', 'Compartir con grupo'),
                  onPressed: item.isVirtual ? null : onShare,
                ),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: tx('common.edit', 'Editar'),
                  onPressed: onEdit,
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: tx('common.delete', 'Eliminar'),
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
