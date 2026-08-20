import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';
import '../../../models/workflows/llm_orchestration_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/overflow_menu_button.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/origin_badge.dart';

class LlmOrchestrationCard extends StatelessWidget {
  const LlmOrchestrationCard({
    required this.item,
    required this.connectionsById,
    required this.tx,
    required this.onToggleActive,
    required this.onEdit,
    required this.onConfigure,
    required this.onShare,
    required this.onDelete,
    super.key,
  });

  final LlmOrchestrationItem item;
  final Map<String, ConnectionItem> connectionsById;
  final String Function(String path) tx;
  final VoidCallback onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback onConfigure;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final balanced = item.mode == 'balanced';
    final router = connectionsById[item.routerConnectionId];

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 10),
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
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!item.isActive) ...[
                  const SizedBox(width: 8),
                  InactiveBadge(label: tx('common.inactive')),
                ],
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetadataLabel(
                  text: balanced
                      ? tx('llm_orchestrations.balanced')
                      : tx('llm_orchestrations.stack'),
                ),
                _MetadataLabel(
                  text: tx(
                    'llm_orchestrations.candidate_count',
                  ).replaceAll('{{count}}', '${item.candidates.length}'),
                ),
                if (item.shared)
                  _MetadataLabel(
                    text: item.bindingConfigured
                        ? tx('llm_orchestrations.binding_ready')
                        : tx('llm_orchestrations.binding_pending'),
                  ),
              ],
            ),
            if (balanced) ...[
              const SizedBox(height: 12),
              Text(
                tx('llm_orchestrations.router'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _connectionLabel(router, item.routerConnectionId),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              balanced
                  ? tx('llm_orchestrations.candidates')
                  : tx('llm_orchestrations.execution_order'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...item.candidates.asMap().entries.map((entry) {
              final candidate = entry.value;
              final connection = connectionsById[candidate.connectionId];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${entry.key + 1}'.padLeft(2, '0'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _connectionLabel(
                              connection,
                              candidate.connectionId,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (candidate.routingHint.isNotEmpty)
                            Text(
                              candidate.routingHint,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 5),
            Row(
              children: [
                OriginBadge(
                  propertyType: item.propertyType,
                  ownerLabel: tx('common.owner'),
                  linkedLabel: tx('common.linked'),
                  forkLabel: tx('common.fork'),
                ),
                const Spacer(),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: tx('common.edit'),
                    onPressed: onEdit,
                  ),
                if (item.shared)
                  ActionIconButton(
                    icon: Icons.tune_outlined,
                    tooltip: tx('llm_orchestrations.configure_connections'),
                    onPressed: onConfigure,
                  ),
                if (!item.readOnly)
                  OverflowMenuButton(
                    tooltip: tx('common.more_actions'),
                    actions: _overflowActions(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return item.isActive ? card : dimmedWhenInactive(context, card);
  }

  /// Con el blanco táctil a 48 px, las cuatro acciones más el badge de origen
  /// desbordaban 16 px a ancho de móvil. Editar se queda a la vista, como en
  /// el resto de tarjetas; lo demás pasa al menú.
  List<OverflowMenuAction> _overflowActions() {
    return [
      if (!item.readOnly) ...[
        OverflowMenuAction(
          icon: item.isActive
              ? Icons.toggle_on_outlined
              : Icons.toggle_off_outlined,
          label: item.isActive
              ? tx('common.deactivate')
              : tx('common.activate'),
          onSelected: onToggleActive,
        ),
        OverflowMenuAction(
          icon: Icons.group_add_outlined,
          label: tx('common.share_group'),
          onSelected: onShare,
        ),
        OverflowMenuAction(
          icon: Icons.delete_outline,
          label: tx('common.delete'),
          onSelected: onDelete,
          danger: true,
          separatedBefore: true,
        ),
      ],
    ];
  }

  String _connectionLabel(ConnectionItem? connection, String fallback) {
    if (connection == null) {
      return fallback.isEmpty
          ? tx('llm_orchestrations.connection_unassigned')
          : fallback;
    }
    if (connection.model.isEmpty) return connection.name;
    return '${connection.name} · ${connection.model}';
  }
}

class _MetadataLabel extends StatelessWidget {
  const _MetadataLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}
