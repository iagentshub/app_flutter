import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../models/agents/agent_models.dart';
import '../../../shared/graph/graph_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/overflow_menu_button.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_graph_button.dart';
import '../../../shared/widgets/token_usage_badge.dart';

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
    this.skillNames = const {},
    this.knowledgeNames = const {},
    this.promptNames = const {},
    this.toolNames = const {},
    this.connectionNames = const {},
    this.onToggleActive,
    super.key,
  });

  final AgentItem item;
  final AgentCardText tx;

  /// id → nombre — el agente solo guarda IDs de sus skills/knowledge/prompts,
  /// así que sin esto el grafo de contenido mostraría el ID en vez del nombre.
  final Map<String, String> skillNames;
  final Map<String, String> knowledgeNames;
  final Map<String, String> promptNames;
  final Map<String, String> toolNames;

  /// id de conexión → nombre del modelo (ej. "gpt-4o") — igual que
  /// [skillNames], sin esto la card mostraría el id crudo de la conexión.
  final Map<String, String> connectionNames;
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
          label: connectionNames[item.connectionId] ?? item.connectionId,
          type: 'connection',
        ),
      );
    }
    for (final skill in item.skills) {
      nodes.add(
        GraphNode(
          id: 'skill-$skill',
          label: skillNames[skill] ?? skill,
          type: 'skill',
        ),
      );
    }
    for (final knowledge in item.knowledge) {
      nodes.add(
        GraphNode(
          id: 'knowledge-$knowledge',
          label: knowledgeNames[knowledge] ?? knowledge,
          type: 'knowledge',
        ),
      );
    }
    for (final prompt in item.prompts) {
      nodes.add(
        GraphNode(
          id: 'prompt-$prompt',
          label: promptNames[prompt] ?? prompt,
          type: 'prompt',
        ),
      );
    }
    for (final tool in item.tools) {
      nodes.add(
        GraphNode(
          id: 'tool-$tool',
          label: toolNames[tool] ?? tool,
          type: 'tool',
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

  /// Ocho acciones no caben en la fila de una tarjeta a ancho de móvil (328 px
  /// en la rejilla de un teléfono de 360): el `Row` desbordaba 70 px y las
  /// últimas —incluida eliminar— quedaban recortadas fuera y sin poder
  /// pulsarse. Solo se quedan a la vista las tres frecuentes; el resto entra
  /// en el menú, que siempre cabe.
  List<OverflowMenuAction> _overflowActions() {
    final exportar = tx('agents.export_tooltip', 'Exportar');
    return [
      OverflowMenuAction(
        icon: Icons.group_add_outlined,
        label: tx('common.share_group', 'Compartir con grupo'),
        onSelected: onShare,
      ),
      OverflowMenuAction(
        icon: Icons.history,
        label: tx('history.dialog_title', 'Historial de versiones'),
        onSelected: onHistory,
      ),
      OverflowMenuAction(
        icon: Icons.ios_share_outlined,
        label: '$exportar · ${tx('agents.export_openai', 'OpenAI')}',
        onSelected: () => onExport('openai'),
        separatedBefore: true,
      ),
      OverflowMenuAction(
        icon: Icons.ios_share_outlined,
        label: '$exportar · ${tx('agents.export_claude', 'Claude')}',
        onSelected: () => onExport('claude'),
      ),
      OverflowMenuAction(
        icon: Icons.ios_share_outlined,
        label: '$exportar · ${tx('agents.export_github', 'GitHub Copilot')}',
        onSelected: () => onExport('github'),
      ),
      OverflowMenuAction(
        icon: Icons.ios_share_outlined,
        label: '$exportar · ${tx('agents.export_mcp', 'Servidor MCP')}',
        onSelected: () => onExport('mcp'),
      ),
      if (onToggleActive != null)
        OverflowMenuAction(
          icon: item.isActive
              ? Icons.toggle_on_outlined
              : Icons.toggle_off_outlined,
          label: item.isActive
              ? tx('common.deactivate', 'Desactivar')
              : tx('common.activate', 'Activar'),
          onSelected: onToggleActive!,
          separatedBefore: true,
        ),
      OverflowMenuAction(
        icon: Icons.delete_outline,
        label: tx('common.delete', 'Eliminar'),
        onSelected: onDelete,
        danger: true,
        separatedBefore: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[item.agentType];
    if (item.model.isNotEmpty) subtitleParts.add(item.model);
    if (item.connectionId.isNotEmpty) {
      subtitleParts.add(
        connectionNames[item.connectionId] ?? item.connectionId,
      );
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
                      fontSize: FncFonts.size16,
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
              labelText: (label) => tx('labels.$label', label),
              leading: [
                OriginBadge(
                  shared: item.shared,
                  ownerLabel: tx('common.owner', 'Propietario'),
                  linkedLabel: tx('common.linked', 'Enlazado'),
                ),
                TokenUsageBadge(
                  tokensIn: item.tokensIn,
                  tokensOut: item.tokensOut,
                  tooltip: tx('agents.tokens_tooltip', 'Tokens consumidos'),
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
                    label: Text(tx('agents.chat_action', 'Chat')),
                  ),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: tx('common.edit', 'Editar'),
                  onPressed: onEdit,
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
                  sortGalaxyLabel: tx('graph.sort_galaxy', 'Galaxia'),
                  showLabelsTooltip: tx(
                    'graph.show_labels_tooltip',
                    'Mostrar nombres',
                  ),
                  hideLabelsTooltip: tx(
                    'graph.hide_labels_tooltip',
                    'Ocultar nombres',
                  ),
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
                OverflowMenuButton(
                  tooltip: tx('common.more_actions', 'Más acciones'),
                  actions: _overflowActions(),
                ),
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
