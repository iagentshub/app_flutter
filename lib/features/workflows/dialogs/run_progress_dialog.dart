part of '../pages/workflows_page.dart';

enum _RunNodeStatus { waiting, running, done, error }

class _RunProgressDialog extends StatefulWidget {
  const _RunProgressDialog({
    required this.workflowName,
    required this.nodes,
    required this.edges,
    required this.stream,
    required this.tx,
  });

  final String workflowName;
  final List<dynamic> nodes;
  final List<dynamic> edges;
  final Stream<Map<String, dynamic>> stream;
  final String Function(String path, String fallback) tx;

  @override
  State<_RunProgressDialog> createState() => _RunProgressDialogState();
}

class _RunProgressDialogState extends State<_RunProgressDialog> {
  final List<Map<String, dynamic>> _events = [];
  final Map<String, _RunNodeStatus> _nodeStatus = {};
  final Map<String, String> _nodeOutputs = {};
  final Map<String, int> _nodeIterations = {};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String? _activeNodeId;
  String? _finalOutput;
  String? _errorMessage;
  bool _running = true;

  List<Map<String, dynamic>> get _nodes => widget.nodes
      .whereType<Map>()
      .map((node) => Map<String, dynamic>.from(node))
      .toList();

  int get _completedCount => _nodeStatus.values
      .where((status) => status == _RunNodeStatus.done)
      .length;

  @override
  void initState() {
    super.initState();
    for (final node in _nodes) {
      final id = node['id']?.toString() ?? '';
      if (id.isNotEmpty) _nodeStatus[id] = _RunNodeStatus.waiting;
    }
    _subscription = widget.stream.listen(
      _handleEvent,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = _readError(error);
          if (_activeNodeId != null) {
            _nodeStatus[_activeNodeId!] = _RunNodeStatus.error;
          }
          _running = false;
        });
      },
      onDone: () {
        if (mounted) setState(() => _running = false);
      },
    );
  }

  void _handleEvent(Map<String, dynamic> event) {
    if (!mounted || event['type'] == 'heartbeat') return;
    setState(() {
      _events.add(event);
      final type = event['type']?.toString() ?? '';
      final nodeId = event['node_id']?.toString() ?? '';
      if (nodeId.isNotEmpty && event['iteration'] is num) {
        _nodeIterations[nodeId] = (event['iteration'] as num).toInt();
      }
      switch (type) {
        case 'stage_started':
        case 'evaluation_started':
          _activeNodeId = nodeId;
          if (nodeId.isNotEmpty) {
            _nodeStatus[nodeId] = _RunNodeStatus.running;
          }
          break;
        case 'stage_done':
          _activeNodeId = nodeId;
          if (nodeId.isNotEmpty) {
            _nodeStatus[nodeId] = _RunNodeStatus.done;
            _nodeOutputs[nodeId] = event['output']?.toString() ?? '';
          }
          break;
        case 'evaluation_done':
          _activeNodeId = nodeId;
          if (nodeId.isNotEmpty) {
            _nodeStatus[nodeId] = event['approved'] == true
                ? _RunNodeStatus.done
                : _RunNodeStatus.running;
          }
          break;
        case 'loop_iteration_started':
          final targetId = event['target_node_id']?.toString() ?? '';
          for (final id in _loopResetIds(nodeId, targetId)) {
            _nodeStatus[id] = id == targetId
                ? _RunNodeStatus.running
                : _RunNodeStatus.waiting;
          }
          _activeNodeId = targetId.isEmpty ? nodeId : targetId;
          break;
        case 'loop_limit_reached':
        case 'error':
          if (nodeId.isNotEmpty) _nodeStatus[nodeId] = _RunNodeStatus.error;
          _activeNodeId = nodeId.isEmpty ? _activeNodeId : nodeId;
          _errorMessage =
              event['message']?.toString() ??
              widget.tx(
                'workflows.error_running_generic',
                'Error ejecutando workflow',
              );
          _running = false;
          break;
        case 'workflow_done':
          _finalOutput = event['output']?.toString();
          _activeNodeId = null;
          _running = false;
          break;
      }
    });
  }

  Set<String> _loopResetIds(String sourceId, String targetId) {
    if (targetId.isEmpty) return {sourceId};
    final result = <String>{targetId, sourceId};
    var changed = true;
    while (changed) {
      changed = false;
      for (final rawEdge in widget.edges.whereType<Map>()) {
        if (rawEdge['type']?.toString() == 'loop') continue;
        final source = rawEdge['source']?.toString() ?? '';
        final target = rawEdge['target']?.toString() ?? '';
        if (result.contains(source) && !result.contains(target)) {
          result.add(target);
          changed = true;
        }
      }
    }
    return result;
  }

  String _readError(Object error) {
    if (error is ApiError) return error.message;
    final message = error.toString().trim();
    return message.isNotEmpty && message != 'Exception'
        ? message
        : widget.tx(
            'workflows.error_connection',
            'Error de conexión durante la ejecución',
          );
  }

  String _nodeLabel(Map<String, dynamic> node) {
    final label = node['label']?.toString().trim() ?? '';
    if (label.isNotEmpty) return label;
    return node['agent_id']?.toString() ??
        widget.tx('workflows.default_agent_label', 'Agente');
  }

  String _statusLabel(_RunNodeStatus status) => switch (status) {
    _RunNodeStatus.waiting => widget.tx('workflows.node_waiting', 'Pendiente'),
    _RunNodeStatus.running => widget.tx('workflows.node_running', 'En curso'),
    _RunNodeStatus.done => widget.tx('workflows.node_done', 'Completado'),
    _RunNodeStatus.error => widget.tx('workflows.run_status_error', 'Error'),
  };

  Color _statusColor(BuildContext context, _RunNodeStatus status) {
    final colors = Theme.of(context).colorScheme;
    return switch (status) {
      _RunNodeStatus.waiting => colors.outline,
      _RunNodeStatus.running => colors.primary,
      _RunNodeStatus.done => Colors.green.shade600,
      _RunNodeStatus.error => colors.error,
    };
  }

  IconData _statusIcon(_RunNodeStatus status, bool evaluator) =>
      switch (status) {
        _RunNodeStatus.waiting =>
          evaluator ? Icons.rule_outlined : Icons.smart_toy_outlined,
        _RunNodeStatus.running => Icons.play_arrow_rounded,
        _RunNodeStatus.done => Icons.check_rounded,
        _RunNodeStatus.error => Icons.priority_high_rounded,
      };

  Widget _flowNode(BuildContext context, Map<String, dynamic> node, int index) {
    final colors = Theme.of(context).colorScheme;
    final id = node['id']?.toString() ?? '';
    final status = _nodeStatus[id] ?? _RunNodeStatus.waiting;
    final accent = _statusColor(context, status);
    final selected = _activeNodeId == id;
    final iteration = _nodeIterations[id] ?? 1;
    final evaluator = node['kind']?.toString() == 'evaluator';
    return InkWell(
      onTap: () => setState(() => _activeNodeId = id),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: .10)
              : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : colors.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .14),
                shape: BoxShape.circle,
              ),
              child: status == _RunNodeStatus.running
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: accent,
                      ),
                    )
                  : Icon(
                      _statusIcon(status, evaluator),
                      size: 19,
                      color: accent,
                    ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}. ${_nodeLabel(node)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    iteration > 1
                        ? '${_statusLabel(status)} · Vuelta $iteration'
                        : _statusLabel(status),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flow(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final nodes = _nodes;
    if (nodes.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
      itemCount: nodes.length,
      itemBuilder: (context, index) => Column(
        children: [
          _flowNode(context, nodes[index], index),
          if (index < nodes.length - 1)
            Container(width: 2, height: 14, color: colors.outlineVariant),
        ],
      ),
    );
  }

  Widget _detailPanel(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Map<String, dynamic>? selectedNode;
    for (final node in _nodes) {
      if (node['id']?.toString() == _activeNodeId) {
        selectedNode = node;
        break;
      }
    }
    final output = _activeNodeId == null ? null : _nodeOutputs[_activeNodeId!];
    final title = selectedNode == null
        ? (_running
              ? widget.tx(
                  'workflows.run_waiting_first_event',
                  'Preparando la orquestación…',
                )
              : widget.tx('workflows.final_output_title', 'Resultado final'))
        : _nodeLabel(selectedNode);
    final body = _errorMessage ?? output ?? _finalOutput;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _errorMessage != null
                    ? Icons.error_outline
                    : selectedNode == null
                    ? Icons.flag_outlined
                    : Icons.notes_rounded,
                size: 19,
                color: _errorMessage != null ? colors.error : colors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: body == null || body.trim().isEmpty
                ? Center(
                    child: Text(
                      _running
                          ? widget.tx(
                              'workflows.node_output_waiting',
                              'Aquí aparecerá el resultado de este paso.',
                            )
                          : widget.tx(
                              'workflows.no_output',
                              'Sin resultado disponible',
                            ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                : SingleChildScrollView(
                    child: SelectableText(
                      body,
                      style: TextStyle(
                        height: 1.5,
                        color: _errorMessage != null
                            ? colors.error
                            : colors.onSurface,
                      ),
                    ),
                  ),
          ),
          if (_events.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '${_events.length} eventos recibidos',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = _nodes.length;
    final progress = total == 0 ? 0.0 : _completedCount / total;
    final statusColor = _errorMessage != null
        ? colors.error
        : _running
        ? colors.primary
        : Colors.green.shade600;
    final statusLabel = _errorMessage != null
        ? widget.tx('workflows.run_status_error', 'Error')
        : _running
        ? widget.tx('workflows.run_status_running', 'En curso')
        : widget.tx('workflows.run_status_done', 'Completada');

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tx('workflows.run_live_title', 'Ejecución en vivo'),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.workflowName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 820),
        height: dialogContentHeight(context, 540),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: colors.surfaceContainerHighest,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$_completedCount/$total pasos',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 650) {
                    return Column(
                      children: [
                        Expanded(flex: 3, child: _flow(context)),
                        const SizedBox(height: 12),
                        Expanded(flex: 2, child: _detailPanel(context)),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      SizedBox(width: 320, child: _flow(context)),
                      const SizedBox(width: 14),
                      Expanded(child: _detailPanel(context)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        PrimaryButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: Text(
            _running
                ? widget.tx('workflows.running_label', 'Ejecutando…')
                : widget.tx('common.close', 'Cerrar'),
          ),
        ),
      ],
    );
  }
}
