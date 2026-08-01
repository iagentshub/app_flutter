import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../models/agents/agent_models.dart';
import '../../../shared/graph/graph_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_graph_button.dart';

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
    this.onToggleActive,
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

  /// Activar/desactivar (borrado suave). Si es null, no se ofrece la acción
  /// (p. ej. en recursos compartidos de solo lectura).
  final VoidCallback? onToggleActive;

  /// Nodos del grafo de contenido: el agente en el centro y sus skills,
  /// knowledge, conexión y memoria alrededor.
  List<GraphNode> _graphNodes() {
    final nodes = [
      GraphNode(
        id: 'root',
        label: item.name,
        type: 'agent',
        description: item.description,
      ),
    ];
    if (item.connectionId.isNotEmpty) {
      nodes.add(
        GraphNode(
          id: 'connection',
          label: item.connectionId,
          type: 'connection',
        ),
      );
    }
    for (final skill in item.skills) {
      nodes.add(GraphNode(id: 'skill-$skill', label: skill, type: 'skill'));
    }
    for (final knowledge in item.knowledge) {
      nodes.add(
        GraphNode(
          id: 'knowledge-$knowledge',
          label: knowledge,
          type: 'knowledge',
        ),
      );
    }
    if (item.useMemory) {
      nodes.add(
        GraphNode(
          id: 'memory',
          label: item.memoryFile.isEmpty ? 'memory' : item.memoryFile,
          type: 'memory',
        ),
      );
    }
    return nodes;
  }

  List<GraphEdge> _graphEdges(List<GraphNode> nodes) => [
    for (final node in nodes.skip(1))
      GraphEdge(sourceId: 'root', targetId: node.id),
  ];

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[item.agentType];
    if (item.model.isNotEmpty) subtitleParts.add(item.model);
    if (item.connectionId.isNotEmpty) {
      subtitleParts.add('conn: ${item.connectionId}');
    }
    final graphNodes = _graphNodes();

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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!item.isActive) ...[
                  const SizedBox(width: 8),
                  InactiveBadge(label: tx('common.inactive', 'Inactivo')),
                ],
              ],
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
                ResourceGraphButton(
                  tooltip: tx('agents.graph_tooltip', 'Ver grafo de contenido'),
                  dialogTitle: item.name,
                  nodes: graphNodes,
                  edges: _graphEdges(graphNodes),
                  rootId: 'root',
                  closeLabel: tx('common.close', 'Cerrar'),
                  searchHint: tx('graph.search_hint', 'Buscar en el grafo...'),
                  sortTooltip: tx('graph.sort_tooltip', 'Ordenar'),
                  sortHierarchyVerticalLabel: tx(
                    'graph.sort_hierarchy_vertical',
                    'Jerárquico (arriba-abajo)',
                  ),
                  sortHierarchyHorizontalLabel: tx(
                    'graph.sort_hierarchy_horizontal',
                    'Jerárquico (izquierda-derecha)',
                  ),
                  sortRadialLabel: tx('graph.sort_radial', 'Radial (círculos)'),
                  quickViewDescriptionLabel: tx(
                    'graph.quick_view_description',
                    'Descripción',
                  ),
                  quickViewNoDescriptionLabel: tx(
                    'graph.quick_view_no_description',
                    'Sin descripción',
                  ),
                  quickViewConnectionsLabel: tx(
                    'graph.quick_view_connections',
                    'Conexiones',
                  ),
                  quickViewNoConnectionsLabel: tx(
                    'graph.quick_view_no_connections',
                    'Sin conexiones',
                  ),
                  emptyLabel: tx(
                    'agents.graph_empty',
                    'Este agente todavía no tiene skills, knowledge, conexión ni memoria.',
                  ),
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
                if (onToggleActive != null)
                  ActionIconButton(
                    icon: item.isActive
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                    tooltip: item.isActive
                        ? tx('common.deactivate', 'Desactivar')
                        : tx('common.activate', 'Activar'),
                    onPressed: onToggleActive,
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

    if (item.isActive) return card;
    return Opacity(opacity: 0.6, child: card);
  }
}
