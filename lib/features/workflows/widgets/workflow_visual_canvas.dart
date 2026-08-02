import 'package:flutter/material.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

import '../../../models/agents/agent_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../cards/workflow_node_card.dart';
import '../models/workflow_graph_validation.dart';
import '../models/workflow_step_draft.dart';

typedef WorkflowConnectionCallback =
    void Function(String sourceId, String targetId, String type);

void _ignoreConnection(String _, String _, String _) {}

/// Interactive node canvas that mirrors the workflow definition used by the
/// backend. Sequence edges are created by dragging between ports; loop edges
/// remain editable from the inspector and are rendered in orange.
///
/// El mismo lienzo se usa en dos modos:
/// * edición ([NodeFlowBehavior.design]), donde marca el nodo seleccionado y
///   los que tienen errores de validación;
/// * ejecución ([NodeFlowBehavior.inspect]), donde pinta el estado que llega
///   por SSE sobre el grafo que el usuario diseñó.
class WorkflowVisualCanvas extends StatefulWidget {
  const WorkflowVisualCanvas({
    required this.steps,
    required this.agents,
    required this.selectedStepId,
    required this.onStepSelected,
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
    this.onStepMoved,
    this.onStepDeleted,
    this.onConnectionCreated = _ignoreConnection,
    this.onConnectionDeleted = _ignoreConnection,
    this.canCreateConnection,
    this.behavior = NodeFlowBehavior.design,
    this.nodeStatuses = const {},
    this.issueNodeIds = const {},
    this.iterations = const {},
    super.key,
  });

  final List<WorkflowStepDraft> steps;
  final List<AgentItem> agents;
  final String? selectedStepId;
  final ValueChanged<String> onStepSelected;
  final void Function(String stepId, Offset position)? onStepMoved;
  final ValueChanged<String>? onStepDeleted;
  final WorkflowConnectionCallback onConnectionCreated;
  final WorkflowConnectionCallback onConnectionDeleted;
  final bool Function(String sourceId, String targetId)? canCreateConnection;
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

  /// Qué puede hacer el usuario con el lienzo.
  final NodeFlowBehavior behavior;

  /// Estado de ejecución por nodo; vacío en modo edición.
  final Map<String, WorkflowNodeVisualStatus> nodeStatuses;

  /// Nodos que incumplen alguna regla de validación.
  final Set<String> issueNodeIds;

  /// Vuelta actual por nodo, para los ciclos.
  final Map<String, int> iterations;

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

  Offset _positionFor(WorkflowStepDraft step) {
    if (step.positionX != null && step.positionY != null) {
      return Offset(step.positionX!, step.positionY!);
    }
    // Un workflow guardado sin posiciones se coloca siguiendo el sentido del
    // flujo en vez de por índice de array, que no significaba nada.
    return layeredLayout(widget.steps)[step.id] ?? const Offset(80, 80);
  }

  Node<WorkflowStepDraft> _nodeForStep(WorkflowStepDraft step) {
    final position = _positionFor(step);
    step.positionX ??= position.dx;
    step.positionY ??= position.dy;
    return Node<WorkflowStepDraft>(
      id: step.id,
      type: step.kind,
      position: position,
      size: _nodeSize,
      locked: !widget.behavior.canDrag,
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
        final existing = _controller.getNode(step.id);
        if (existing == null) {
          _controller.addNode(_nodeForStep(step));
          continue;
        }
        // "Auto-organizar" reescribe las posiciones del borrador; sin esto el
        // lienzo se quedaría con las viejas.
        final desired = _positionFor(step);
        if (existing.position.value != desired) {
          _controller.setNodePosition(step.id, desired);
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
              behavior: widget.behavior,
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
                    widget.onStepMoved?.call(node.id, position);
                  },
                  onBeforeDelete: (node) async =>
                      widget.behavior.canDelete && widget.steps.length > 1,
                  onDeleted: (node) {
                    if (!_syncing) widget.onStepDeleted?.call(node.id);
                  },
                ),
                connection: ConnectionEvents<WorkflowStepDraft, String>(
                  onCreated: _handleConnectionCreated,
                  onDeleted: _handleConnectionDeleted,
                  onBeforeComplete: (connection) {
                    final allowed =
                        widget.behavior.canCreate &&
                        (widget.canCreateConnection?.call(
                              connection.sourceNode.id,
                              connection.targetNode.id,
                            ) ??
                            true);
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
            // La pista de "arrastra para conectar" solo aplica al editor.
            if (widget.behavior.canCreate)
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
    return WorkflowNodeCard(
      step: step,
      agentName: _agentName(step.agentId),
      agentKindLabel: widget.agentKindLabel,
      evaluatorKindLabel: widget.evaluatorKindLabel,
      selected: widget.selectedStepId == step.id,
      hasIssue: widget.issueNodeIds.contains(step.id),
      status: widget.nodeStatuses[step.id] ?? WorkflowNodeVisualStatus.none,
      iteration: widget.iterations[step.id] ?? 1,
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
