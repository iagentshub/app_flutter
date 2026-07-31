import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../models/agents/agent_models.dart';
import '../../../shared/graph/graph_models.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
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
    required this.onRun,
    required this.onEdit,
    required this.onDelete,
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
  final VoidCallback onRun;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Grafo de contenido a 3 niveles: la orquestación en el centro, sus
  /// pasos (agentes/evaluadores) con las conexiones del editor visual
  /// (secuencia/bucle), y bajo cada paso-agente sus propias skills,
  /// knowledge, conexión y memoria, cuando el agente referenciado está
  /// disponible en [agentsById]. Un recurso compartido por 2+ agentes (misma
  /// skill, knowledge, conexión o fichero de memoria) aparece una única vez,
  /// enlazado desde cada paso que lo use.
  (List<GraphNode>, List<GraphEdge>) _buildGraph() {
    final nodesById = <String, GraphNode>{
      'root': GraphNode(id: 'root', label: item.name, type: 'workflow'),
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
    final metadata = [
      '${item.nodes.length} $stepsLabel',
      '${item.edges.length} $connectionsLabel',
    ];
    final (graphNodes, graphEdges) = _buildGraph();

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
                ResourceGraphButton(
                  tooltip: graphTooltip,
                  dialogTitle: item.name,
                  nodes: graphNodes,
                  edges: graphEdges,
                  rootId: 'root',
                  closeLabel: graphCloseLabel,
                  searchHint: graphSearchHint,
                  emptyLabel: graphEmptyLabel,
                ),
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
