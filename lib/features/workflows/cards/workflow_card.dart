import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../models/agents/agent_models.dart';
import '../../../shared/graph/graph_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_graph_button.dart';
import '../../../models/workflows/workflow_models.dart';

class WorkflowCard extends StatelessWidget {
  const WorkflowCard({
    required this.item,
    required this.agentsById,
    required this.stepsLabel,
    required this.connectionsLabel,
    required this.ownerLabel,
    required this.linkedLabel,
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
    required this.graphSortRadialLabel,
    required this.graphQuickViewDescriptionLabel,
    required this.graphQuickViewNoDescriptionLabel,
    required this.graphQuickViewConnectionsLabel,
    required this.graphQuickViewNoConnectionsLabel,
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
    this.inactiveLabel = 'Inactivo',
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
  final String stepsLabel;
  final String connectionsLabel;
  final String ownerLabel;
  final String linkedLabel;
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
  final String graphSortRadialLabel;
  final String graphQuickViewDescriptionLabel;
  final String graphQuickViewNoDescriptionLabel;
  final String graphQuickViewConnectionsLabel;
  final String graphQuickViewNoConnectionsLabel;
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String inactiveLabel;
  final String activateTooltip;
  final String deactivateTooltip;

  /// Activar/desactivar (borrado suave). Null = acción no disponible.
  final VoidCallback? onToggleActive;

  /// Grafo de contenido a 3 niveles: la orquestación en el centro, sus
  /// pasos (agentes/evaluadores) con las conexiones del editor visual
  /// (secuencia/bucle), y bajo cada paso-agente sus propias skills,
  /// knowledge, conexión y memoria, cuando el agente referenciado está
  /// disponible en [agentsById]. Un recurso compartido por 2+ agentes (misma
  /// skill, knowledge, conexión o fichero de memoria) aparece una única vez,
  /// enlazado desde cada paso que lo use.
  (List<GraphNode>, List<GraphEdge>) _buildGraph() {
    final nodesById = <String, GraphNode>{
      'root': GraphNode(
        id: 'root',
        label: item.name,
        type: 'workflow',
        description: item.description,
      ),
    };
    final edgeKeys = <String>{};
    final edges = <GraphEdge>[];
    final stepIds = <String>{};

    void addEdge(String source, String target, {bool dashed = false}) {
      if (edgeKeys.add('$source>$target')) {
        edges.add(GraphEdge(sourceId: source, targetId: target, dashed: dashed));
      }
    }

    for (final raw in item.nodes) {
      if (raw is! Map) continue;
      final id = raw['id']?.toString() ?? '';
      if (id.isEmpty) continue;
      stepIds.add(id);
      final label = (raw['label']?.toString().isNotEmpty ?? false)
          ? raw['label'].toString()
          : (raw['agent_id']?.toString() ?? id);
      final isEvaluator = raw['kind']?.toString() == 'evaluator';
      nodesById[id] = GraphNode(
        id: id,
        label: label,
        type: isEvaluator ? 'evaluator' : 'agent',
      );

      final agent = agentsById[raw['agent_id']?.toString() ?? ''];
      if (agent == null) continue;
      nodesById[id] = GraphNode(
        id: id,
        label: label,
        type: isEvaluator ? 'evaluator' : 'agent',
        description: agent.description,
      );
      if (agent.connectionId.isNotEmpty) {
        final childId = 'connection:${agent.connectionId}';
        nodesById[childId] = GraphNode(
          id: childId,
          label: agent.connectionId,
          type: 'connection',
        );
        addEdge(id, childId);
      }
      for (final skill in agent.skills) {
        final childId = 'skill:$skill';
        nodesById[childId] = GraphNode(id: childId, label: skill, type: 'skill');
        addEdge(id, childId);
      }
      for (final knowledge in agent.knowledge) {
        final childId = 'knowledge:$knowledge';
        nodesById[childId] = GraphNode(
          id: childId,
          label: knowledge,
          type: 'knowledge',
        );
        addEdge(id, childId);
      }
      if (agent.useMemory) {
        final memoryLabel = agent.memoryFile.isEmpty
            ? 'memory'
            : agent.memoryFile;
        final childId = 'memory:$memoryLabel';
        nodesById[childId] = GraphNode(
          id: childId,
          label: memoryLabel,
          type: 'memory',
        );
        addEdge(id, childId);
      }
    }

    for (final raw in item.edges) {
      if (raw is! Map) continue;
      final source = raw['source']?.toString() ?? '';
      final target = raw['target']?.toString() ?? '';
      if (!nodesById.containsKey(source) || !nodesById.containsKey(target)) {
        continue;
      }
      addEdge(source, target, dashed: raw['type']?.toString() == 'loop');
    }

    final hasIncoming = edges.map((e) => e.targetId).toSet();
    for (final id in stepIds) {
      if (!hasIncoming.contains(id)) {
        addEdge('root', id);
      }
    }

    return (nodesById.values.toList(), edges);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final (graphNodes, graphEdges) = _buildGraph();

    final card = Card(
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
                if (!item.isActive) ...[
                  const SizedBox(width: 8),
                  InactiveBadge(label: inactiveLabel),
                ],
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
                ResourceGraphButton(
                  tooltip: graphTooltip,
                  dialogTitle: item.name,
                  nodes: graphNodes,
                  edges: graphEdges,
                  rootId: 'root',
                  closeLabel: graphCloseLabel,
                  searchHint: graphSearchHint,
                  sortTooltip: graphSortTooltip,
                  sortHierarchyVerticalLabel: graphSortHierarchyVerticalLabel,
                  sortHierarchyHorizontalLabel: graphSortHierarchyHorizontalLabel,
                  sortRadialLabel: graphSortRadialLabel,
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
                    tooltip: item.isActive ? deactivateTooltip : activateTooltip,
                    onPressed: onToggleActive,
                  ),
                  const SizedBox(width: 8),
                ],
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

    if (item.isActive) return card;
    return Opacity(opacity: 0.6, child: card);
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
