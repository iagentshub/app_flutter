import 'package:flutter/material.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

import '../../../models/agents/agent_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../models/workflow_step_draft.dart';

typedef WorkflowConnectionCallback =
    void Function(String sourceId, String targetId, String type);

/// Interactive node canvas that mirrors the workflow definition used by the
/// backend. Sequence edges are created by dragging between ports; loop edges
/// remain editable from the inspector and are rendered in orange.
class WorkflowVisualCanvas extends StatefulWidget {
  const WorkflowVisualCanvas({
    required this.steps,
    required this.agents,
    required this.selectedStepId,
    required this.onStepSelected,
    required this.onStepMoved,
    required this.onStepDeleted,
    required this.onConnectionCreated,
    required this.onConnectionDeleted,
    required this.canCreateConnection,
    required this.fitTooltip,
    required this.zoomInTooltip,
    required this.zoomOutTooltip,
    required this.connectionHint,
    required this.inputLabel,
    required this.outputLabel,
    required this.missingAgentLabel,
    required this.agentKindLabel,
    required this.evaluatorKindLabel,
    required this.loopLabel,
    required this.invalidConnectionMessage,
    super.key,
  });

  final List<WorkflowStepDraft> steps;
  final List<AgentItem> agents;
  final String? selectedStepId;
  final ValueChanged<String> onStepSelected;
  final void Function(String stepId, Offset position) onStepMoved;
  final ValueChanged<String> onStepDeleted;
  final WorkflowConnectionCallback onConnectionCreated;
  final WorkflowConnectionCallback onConnectionDeleted;
  final bool Function(String sourceId, String targetId) canCreateConnection;
  final String fitTooltip;
  final String zoomInTooltip;
  final String zoomOutTooltip;
  final String connectionHint;
  final String inputLabel;
  final String outputLabel;
  final String missingAgentLabel;
  final String agentKindLabel;
  final String evaluatorKindLabel;
  final String loopLabel;
  final String invalidConnectionMessage;

  @override
  State<WorkflowVisualCanvas> createState() => _WorkflowVisualCanvasState();
}

class _WorkflowVisualCanvasState extends State<WorkflowVisualCanvas> {
  static const _nodeSize = Size(232, 116);
  static const _inputPort = 'input';
  static const _outputPort = 'output';

  late final NodeFlowController<WorkflowStepDraft, String> _controller;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _controller = NodeFlowController<WorkflowStepDraft, String>(
      config: NodeFlowConfig(showAttribution: false),
      nodes: widget.steps.map(_nodeForStep).toList(),
      connections: _connectionsFromSteps(widget.steps),
    );
  }

  @override
  void didUpdateWidget(covariant WorkflowVisualCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGraph();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _positionFor(WorkflowStepDraft step, int index) {
    if (step.positionX != null && step.positionY != null) {
      return Offset(step.positionX!, step.positionY!);
    }
    const columns = 3;
    return Offset(80 + (index % columns) * 310, 80 + (index ~/ columns) * 200);
  }

  Node<WorkflowStepDraft> _nodeForStep(WorkflowStepDraft step) {
    final index = widget.steps.indexWhere((item) => item.id == step.id);
    final position = _positionFor(step, index < 0 ? 0 : index);
    step.positionX ??= position.dx;
    step.positionY ??= position.dy;
    return Node<WorkflowStepDraft>(
      id: step.id,
      type: step.kind,
      position: position,
      size: _nodeSize,
      data: step,
      ports: [
        Port(
          id: _inputPort,
          name: widget.inputLabel,
          type: PortType.input,
          position: PortPosition.left,
          offset: Offset(0, _nodeSize.height / 2),
          multiConnections: true,
          tooltip: widget.inputLabel,
        ),
        Port(
          id: _outputPort,
          name: widget.outputLabel,
          type: PortType.output,
          position: PortPosition.right,
          offset: Offset(0, _nodeSize.height / 2),
          multiConnections: true,
          tooltip: widget.outputLabel,
        ),
      ],
    );
  }

  List<Connection<String>> _connectionsFromSteps(
    List<WorkflowStepDraft> steps,
  ) {
    final connections = <Connection<String>>[];
    for (final step in steps) {
      for (final targetId in step.nextStepIds) {
        connections.add(
          Connection<String>(
            id: _connectionId('sequence', step.id, targetId),
            sourceNodeId: step.id,
            sourcePortId: _outputPort,
            targetNodeId: targetId,
            targetPortId: _inputPort,
            data: 'sequence',
          ),
        );
      }
      final loopTargetId = step.loopTargetId;
      if (loopTargetId != null) {
        connections.add(
          Connection<String>(
            id: _connectionId('loop', step.id, loopTargetId),
            sourceNodeId: step.id,
            sourcePortId: _outputPort,
            targetNodeId: loopTargetId,
            targetPortId: _inputPort,
            data: 'loop',
            color: Colors.orangeAccent,
            label: ConnectionLabel(text: widget.loopLabel),
          ),
        );
      }
    }
    return connections;
  }

  String _connectionId(String type, String source, String target) =>
      '$type::$source::$target';

  String _connectionKey(Connection<String> connection) => _connectionId(
    connection.data ?? 'sequence',
    connection.sourceNodeId,
    connection.targetNodeId,
  );

  void _syncGraph() {
    _syncing = true;
    try {
      final desiredNodeIds = widget.steps.map((step) => step.id).toSet();
      for (final nodeId in _controller.nodeIds.toList()) {
        if (!desiredNodeIds.contains(nodeId)) _controller.removeNode(nodeId);
      }
      for (final step in widget.steps) {
        if (_controller.getNode(step.id) == null) {
          _controller.addNode(_nodeForStep(step));
        }
      }

      final desiredConnections = {
        for (final connection in _connectionsFromSteps(widget.steps))
          _connectionKey(connection): connection,
      };
      final existingConnections = {
        for (final connection in _controller.connections)
          _connectionKey(connection): connection,
      };
      for (final entry in existingConnections.entries) {
        if (!desiredConnections.containsKey(entry.key)) {
          _controller.removeConnection(entry.value.id);
        }
      }
      for (final entry in desiredConnections.entries) {
        if (!existingConnections.containsKey(entry.key)) {
          _controller.addConnection(entry.value);
        }
      }
    } finally {
      _syncing = false;
    }
  }

  void _handleConnectionCreated(Connection<String> connection) {
    if (_syncing) return;
    widget.onConnectionCreated(
      connection.sourceNodeId,
      connection.targetNodeId,
      connection.data ?? 'sequence',
    );
  }

  void _handleConnectionDeleted(Connection<String> connection) {
    if (_syncing) return;
    widget.onConnectionDeleted(
      connection.sourceNodeId,
      connection.targetNodeId,
      connection.data ?? 'sequence',
    );
  }

  String _agentName(String agentId) {
    for (final agent in widget.agents) {
      if (agent.id == agentId) return agent.name;
    }
    return widget.missingAgentLabel;
  }

  NodeFlowTheme _canvasTheme(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? NodeFlowTheme.dark : NodeFlowTheme.light;
    final connection = base.connectionTheme.copyWith(
      color: colors.outline,
      selectedColor: colors.primary,
      highlightColor: colors.primary,
      highlightBorderColor: colors.primary,
      strokeWidth: 1.7,
      selectedStrokeWidth: 2.4,
      endPoint: ConnectionEndPoint.triangle,
      endpointColor: colors.outline,
      endpointBorderColor: colors.outline,
      cornerRadius: 10,
      portExtension: 24,
      backEdgeGap: 28,
    );
    return base.copyWith(
      backgroundColor: colors.surfaceContainerLowest,
      connectionTheme: connection,
      temporaryConnectionTheme: connection.copyWith(
        color: colors.primary,
        dashPattern: const [5, 4],
      ),
      portTheme: base.portTheme.copyWith(
        size: const Size.square(12),
        color: colors.surfaceContainerHighest,
        connectedColor: colors.primary,
        highlightColor: colors.primary,
        highlightBorderColor: colors.onPrimary,
        borderColor: colors.outline,
        borderWidth: 1.5,
      ),
      gridTheme: base.gridTheme.copyWith(
        color: colors.outlineVariant.withValues(alpha: .55),
        size: 24,
        thickness: .75,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            NodeFlowEditor<WorkflowStepDraft, String>(
              controller: _controller,
              theme: _canvasTheme(context),
              nodeBuilder: _buildNode,
              events: NodeFlowEvents<WorkflowStepDraft, String>(
                onInit: () => WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _controller.fitToView(),
                ),
                node: NodeEvents<WorkflowStepDraft>(
                  onTap: (node) => widget.onStepSelected(node.id),
                  onSelected: (node) {
                    if (node != null) widget.onStepSelected(node.id);
                  },
                  onDragStop: (node) {
                    final position = node.visualPosition.value;
                    _controller.setNodePosition(node.id, position);
                    widget.onStepMoved(node.id, position);
                  },
                  onBeforeDelete: (node) async => widget.steps.length > 1,
                  onDeleted: (node) {
                    if (!_syncing) widget.onStepDeleted(node.id);
                  },
                ),
                connection: ConnectionEvents<WorkflowStepDraft, String>(
                  onCreated: _handleConnectionCreated,
                  onDeleted: _handleConnectionDeleted,
                  onBeforeComplete: (connection) {
                    final allowed = widget.canCreateConnection(
                      connection.sourceNode.id,
                      connection.targetNode.id,
                    );
                    return allowed
                        ? const ConnectionValidationResult.allow()
                        : ConnectionValidationResult.deny(
                            reason: widget.invalidConnectionMessage,
                            showMessage: true,
                          );
                  },
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _CanvasControls(
                fitTooltip: widget.fitTooltip,
                zoomInTooltip: widget.zoomInTooltip,
                zoomOutTooltip: widget.zoomOutTooltip,
                onFit: _controller.fitToView,
                onZoomIn: () => _controller.zoomBy(.15),
                onZoomOut: () => _controller.zoomBy(-.15),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface.withValues(alpha: .9),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      child: Text(
                        widget.connectionHint,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNode(BuildContext context, Node<WorkflowStepDraft> node) {
    final step = node.data;
    final colors = Theme.of(context).colorScheme;
    final evaluator = step.kind == 'evaluator';
    final selected = widget.selectedStepId == step.id;
    final accent = evaluator ? colors.tertiary : colors.primary;
    final label = step.label.trim().isEmpty
        ? _agentName(step.agentId)
        : step.label;

    return Container(
      key: ValueKey('workflow-node-${step.id}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? accent : colors.outlineVariant,
          width: selected ? 2 : 1,
        ),
        boxShadow: [
          if (selected)
            BoxShadow(
              color: accent.withValues(alpha: .16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  evaluator ? Icons.rule_rounded : Icons.smart_toy_outlined,
                  size: 17,
                  color: accent,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _agentName(step.agentId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            (evaluator ? widget.evaluatorKindLabel : widget.agentKindLabel)
                .toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}

class _CanvasControls extends StatelessWidget {
  const _CanvasControls({
    required this.fitTooltip,
    required this.zoomInTooltip,
    required this.zoomOutTooltip,
    required this.onFit,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final String fitTooltip;
  final String zoomInTooltip;
  final String zoomOutTooltip;
  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface.withValues(alpha: .94),
      elevation: 3,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              tooltip: zoomOutTooltip,
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove, size: 19),
            ),
            AppIconButton(
              tooltip: fitTooltip,
              onPressed: onFit,
              icon: const Icon(Icons.fit_screen_outlined, size: 19),
            ),
            AppIconButton(
              tooltip: zoomInTooltip,
              onPressed: onZoomIn,
              icon: const Icon(Icons.add, size: 19),
            ),
          ],
        ),
      ),
    );
  }
}
