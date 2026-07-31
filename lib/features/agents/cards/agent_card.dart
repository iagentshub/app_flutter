import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../models/agents/agent_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';

typedef AgentCardText = String Function(String path, String fallback);

/// Presentación reutilizable de un agente.
///
/// Las operaciones se inyectan como callbacks para que la card no conozca
/// repositorios, sesión ni navegación.
class AgentCard extends StatelessWidget {
  const AgentCard({
    required this.item,
    required this.tx,
    required this.onChat,
    required this.onExport,
    required this.onShare,
    required this.onHistory,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final AgentItem item;
  final AgentCardText tx;
  final VoidCallback onChat;
  final ValueChanged<String> onExport;
  final VoidCallback onShare;
  final VoidCallback onHistory;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[item.agentType];
    if (item.model.isNotEmpty) subtitleParts.add(item.model);
    if (item.connectionId.isNotEmpty) {
      subtitleParts.add('conn: ${item.connectionId}');
    }

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
            Text(subtitleParts.join(' · ')),
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
                  ownerLabel: tx('common.owner', 'Propietario'),
                  linkedLabel: tx('common.linked', 'Enlazado'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Tooltip(
                  message: item.connectionId.isEmpty
                      ? tx(
                          'agents.chat_no_connection',
                          'Configura una conexión para este agente',
                        )
                      : '',
                  child: PrimaryButton.icon(
                    onPressed: item.connectionId.isEmpty ? null : onChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: tx('agents.export_tooltip', 'Exportar'),
                  icon: const Icon(Icons.ios_share_outlined, size: 18),
                  onSelected: onExport,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'openai',
                      child: Text(tx('agents.export_openai', 'OpenAI')),
                    ),
                    PopupMenuItem(
                      value: 'claude',
                      child: Text(tx('agents.export_claude', 'Claude')),
                    ),
                    PopupMenuItem(
                      value: 'github',
                      child: Text(tx('agents.export_github', 'GitHub Copilot')),
                    ),
                    PopupMenuItem(
                      value: 'mcp',
                      child: Text(tx('agents.export_mcp', 'Servidor MCP')),
                    ),
                  ],
                ),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: tx('common.share_group', 'Compartir con grupo'),
                  onPressed: onShare,
                ),
                ActionIconButton(
                  icon: Icons.history,
                  tooltip: tx('history.dialog_title', 'Historial de versiones'),
                  onPressed: onHistory,
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
