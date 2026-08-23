import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../shared/graph/resource_graph_builder.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/overflow_menu_button.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_graph_button.dart';
import '../../../shared/widgets/token_usage_badge.dart';
import '../../../utils/i18n.dart';

typedef AgentCardText = String Function(String path);

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
    this.knowledgePackNames = const {},
    this.knowledgePackItems = const {},
    this.promptNames = const {},
    this.toolNames = const {},
    this.connectionNames = const {},
    this.onToggleActive,
    this.inProgress = false,
    super.key,
  });

  final AgentItem item;
  final AgentCardText tx;

  /// id → nombre — el agente solo guarda IDs de sus skills/knowledge/prompts,
  /// así que sin esto el grafo de contenido mostraría el ID en vez del nombre.
  final Map<String, String> skillNames;
  final Map<String, String> knowledgeNames;
  final Map<String, String> knowledgePackNames;
  final Map<String, List<KnowledgeItem>> knowledgePackItems;
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
  final bool inProgress;

  /// Catálogo de nombres que el grafo necesita para no enseñar ids crudos.
  ResourceNames get _graphNames => ResourceNames(
    skills: skillNames,
    prompts: promptNames,
    tools: toolNames,
    knowledge: knowledgeNames,
    packs: knowledgePackNames,
    connections: connectionNames,
    packItems: knowledgePackItems,
  );

  /// Ocho acciones no caben en la fila de una tarjeta a ancho de móvil (328 px
  /// en la rejilla de un teléfono de 360): el `Row` desbordaba 70 px y las
  /// últimas —incluida eliminar— quedaban recortadas fuera y sin poder
  /// pulsarse. Solo se quedan a la vista las tres frecuentes; el resto entra
  /// en el menú, que siempre cabe.
  List<OverflowMenuAction> _overflowActions() {
    final exportar = tx('agents.export_tooltip');
    return [
      if (!item.readOnly)
        OverflowMenuAction(
          icon: Icons.group_add_outlined,
          label: tx('common.share_group'),
          onSelected: onShare,
        ),
      OverflowMenuAction(
        icon: Icons.history,
        label: tx('history.dialog_title'),
        onSelected: onHistory,
      ),
      if (!item.readOnly) ...[
        OverflowMenuAction(
          icon: Icons.ios_share_outlined,
          label: '$exportar · ${tx('agents.export_openai')}',
          onSelected: () => onExport('openai'),
          separatedBefore: true,
        ),
        OverflowMenuAction(
          icon: Icons.ios_share_outlined,
          label: '$exportar · ${tx('agents.export_claude')}',
          onSelected: () => onExport('claude'),
        ),
        OverflowMenuAction(
          icon: Icons.ios_share_outlined,
          label: '$exportar · ${tx('agents.export_github')}',
          onSelected: () => onExport('github'),
        ),
        OverflowMenuAction(
          icon: Icons.ios_share_outlined,
          label: '$exportar · ${tx('agents.export_mcp')}',
          onSelected: () => onExport('mcp'),
        ),
      ],
      if (onToggleActive != null)
        OverflowMenuAction(
          icon: item.isActive
              ? Icons.toggle_on_outlined
              : Icons.toggle_off_outlined,
          label: item.isActive
              ? tx('common.deactivate')
              : tx('common.activate'),
          onSelected: onToggleActive!,
          separatedBefore: true,
        ),
      if (!item.readOnly)
        OverflowMenuAction(
          icon: Icons.delete_outline,
          label: tx('common.delete'),
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
                  InactiveBadge(label: tx('common.inactive')),
                ],
                if (inProgress) ...[
                  const SizedBox(width: 8),
                  Chip(
                    avatar: const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    label: Text(tx('common.in_progress')),
                    visualDensity: VisualDensity.compact,
                  ),
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
              labels: item.displayLabels,
              labelText: (label) => trOr('labels.$label', label),
              leading: [
                OriginBadge(
                  propertyType: item.propertyType,
                  ownerLabel: tx('common.owner'),
                  linkedLabel: tx('common.linked'),
                  forkLabel: tx('common.fork'),
                ),
                TokenUsageBadge(
                  tokensIn: item.tokensIn,
                  tokensOut: item.tokensOut,
                  tooltip: tx('agents.tokens_tooltip'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Tooltip(
                  message: !item.isActive
                      ? tx('agents.chat_inactive')
                      : item.connectionId.isEmpty
                      ? tx('agents.chat_no_connection')
                      : '',
                  child: PrimaryButton.icon(
                    onPressed:
                        !item.isActive ||
                            item.connectionId.isEmpty ||
                            inProgress
                        ? null
                        : onChat,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(tx('agents.chat_action')),
                  ),
                ),
                const Spacer(),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: tx('common.edit'),
                    onPressed: onEdit,
                  ),
                ResourceGraphButton(
                  tooltip: tx('agents.graph_tooltip'),
                  dialogTitle: item.name,
                  buildGraph: () => agentGraph(agent: item, names: _graphNames),
                  closeLabel: tx('common.close'),
                  searchHint: tx('graph.search_hint'),
                  sortTooltip: tx('graph.sort_tooltip'),
                  sortHierarchyVerticalLabel: tx(
                    'graph.sort_hierarchy_vertical',
                  ),
                  sortHierarchyHorizontalLabel: tx(
                    'graph.sort_hierarchy_horizontal',
                  ),
                  sortGalaxyLabel: tx('graph.sort_galaxy'),
                  showLabelsTooltip: tx('graph.show_labels_tooltip'),
                  hideLabelsTooltip: tx('graph.hide_labels_tooltip'),
                  quickViewDescriptionLabel: tx('graph.quick_view_description'),
                  quickViewNoDescriptionLabel: tx(
                    'graph.quick_view_no_description',
                  ),
                  quickViewConnectionsLabel: tx('graph.quick_view_connections'),
                  quickViewNoConnectionsLabel: tx(
                    'graph.quick_view_no_connections',
                  ),
                  emptyLabel: tx('agents.graph_empty'),
                ),
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

    if (item.isActive) return card;
    return dimmedWhenInactive(context, card);
  }
}
