import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../models/agents/agent_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../cards/workflow_node_card.dart';
import '../cards/workflow_run_detail_card.dart';
import '../models/workflow_run_state.dart';
import '../models/workflow_step_draft.dart';
import '../widgets/workflow_visual_canvas.dart';

/// Visor de una ejecución en vivo.
///
/// Pinta el estado sobre el mismo grafo que el usuario diseñó, en vez de una
/// lista plana: así se ven las oleadas paralelas y los rebobinados de ciclo tal
/// y como los ejecuta `backend/app/services/workflow_runner.py`.
class RunProgressDialog extends StatefulWidget {
  const RunProgressDialog({
    required this.workflowName,
    required this.definition,
    required this.agents,
    required this.stream,
    required this.tx,
    this.onCancel,
    super.key,
  });

  final String workflowName;
  final Map<String, dynamic> definition;
  final List<AgentItem> agents;
  final Stream<Map<String, dynamic>> stream;
  final String Function(String path) tx;
  final Future<void> Function()? onCancel;

  @override
  State<RunProgressDialog> createState() => _RunProgressDialogState();
}

class _RunProgressDialogState extends State<RunProgressDialog> {
  late final List<WorkflowStepDraft> _steps;
  late final WorkflowRunState _state;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _ticker;
  String? _selectedStepId;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _steps = stepsFromDefinition(widget.definition);
    _state = WorkflowRunState(steps: _steps);
    _subscription = widget.stream.listen(
      _onEvent,
      onError: (Object error) {
        if (!mounted) return;
        setState(
          () => _state.markStreamError(_readError(error), DateTime.now()),
        );
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _state.markStreamClosed(DateTime.now()));
      },
    );
    // Mantiene vivo el cronómetro del paso en curso entre eventos: una llamada
    // a un LLM puede tardar minutos y sin esto la UI parece congelada.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _state.running) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final changed = _state.apply(event, DateTime.now());
    if (changed) {
      setState(() {
        _selectedStepId ??= _state.activeNodeId;
      });
    }
  }

  String _readError(Object error) {
    if (error is ApiError) return error.message;
    final message = error.toString().trim();
    return message.isNotEmpty && message != 'Exception'
        ? message
        : _tx('workflows.error_connection');
  }

  String _tx(String path) => widget.tx(path);

  String _agentName(String agentId) {
    for (final agent in widget.agents) {
      if (agent.id == agentId) return agent.name;
    }
    return _tx('workflows.default_agent_label');
  }

  /// ponytail: cancelar solo cierra el stream del cliente. El backend no tiene
  /// endpoint de cancelación, así que las tareas del servidor siguen corriendo
  /// y consumiendo tokens. Cancelación real = endpoint nuevo en workflow_runner.
  Future<void> _cancel() async {
    final cancel = widget.onCancel;
    if (cancel != null) {
      setState(() => _cancelling = true);
      try {
        await cancel();
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _cancelling = false;
          _state.markStreamError(_readError(error), DateTime.now());
        });
      }
      return;
    }
    await _subscription?.cancel();
    _subscription = null;
    setState(() => _state.markCancelled(DateTime.now()));
  }

  WorkflowNodeVisualStatus _visualStatus(RunNodeStatus status) =>
      switch (status) {
        RunNodeStatus.waiting => WorkflowNodeVisualStatus.waiting,
        RunNodeStatus.running => WorkflowNodeVisualStatus.running,
        RunNodeStatus.done => WorkflowNodeVisualStatus.done,
        RunNodeStatus.error => WorkflowNodeVisualStatus.error,
      };

  Color _statusColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (_state.error != null) return colors.error;
    if (_state.cancelled) return colors.onSurfaceVariant;
    return _state.running ? colors.primary : FncColors.materialGreen.shade600;
  }

  String _statusLabel() {
    if (_state.error != null) return _tx('workflows.run_status_error');
    if (_state.cancelled) {
      return _tx('workflows.run_cancelled');
    }
    return _state.running
        ? _tx('workflows.run_status_running')
        : _tx('workflows.run_status_done');
  }

  Widget _canvas() {
    return WorkflowVisualCanvas(
      steps: _steps,
      agents: widget.agents,
      selectedStepId: _selectedStepId,
      onStepSelected: (id) => setState(() => _selectedStepId = id),
      behavior: NodeFlowBehavior.inspect,
      nodeStatuses: {
        for (final entry in _state.status.entries)
          entry.key: _visualStatus(entry.value),
      },
      iterations: _state.iterations,
      fitTooltip: _tx('workflow_editor.fit_view'),
      zoomInTooltip: _tx('workflow_editor.zoom_in'),
      zoomOutTooltip: _tx('workflow_editor.zoom_out'),
      inputLabel: _tx('workflow_editor.input_port'),
      outputLabel: _tx('workflow_editor.output_port'),
      missingAgentLabel: _tx('workflow_editor.no_agent'),
      agentKindLabel: _tx('workflow_editor.kind_agent'),
      evaluatorKindLabel: _tx('workflow_editor.kind_evaluator'),
      loopLabel: _tx('workflow_editor.loop_label'),
      invalidConnectionMessage: '',
    );
  }

  Widget _progressBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final total = _state.totalCount;
    final done = _state.completedCount;
    final progress = total == 0 ? 0.0 : done / total;
    final active = _state.activeSince;

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 320),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _tx(
            'workflows.run_progress_steps',
          ).replaceAll('{{done}}', '$done').replaceAll('{{total}}', '$total'),
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (_state.maxIteration > 1) ...[
          const SizedBox(width: 10),
          Text(
            _tx(
              'workflows.loop_round',
            ).replaceAll('{{n}}', '${_state.maxIteration}'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (_state.running && active != null) ...[
          const SizedBox(width: 10),
          Text(
            _tx('workflows.still_working').replaceAll(
              '{{time}}',
              formatRunDuration(DateTime.now().difference(active)),
            ),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final statusColor = _statusColor(context);
    final detail = WorkflowRunDetailCard(
      state: _state,
      steps: _steps,
      selectedStepId: _selectedStepId,
      agentNameFor: _agentName,
      tx: widget.tx,
    );

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tx('workflows.run_live_title')),
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
              '${_statusLabel()} · ${formatRunDuration(_state.elapsed)}',
              style: TextStyle(
                color: statusColor,
                fontSize: FncFonts.size12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 1080),
        height: dialogContentHeight(context, 620),
        child: Column(
          children: [
            _progressBar(context),
            const SizedBox(height: 18),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 780) {
                    return Column(
                      children: [
                        Expanded(flex: 3, child: _canvas()),
                        const SizedBox(height: 12),
                        Expanded(flex: 2, child: detail),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(flex: 3, child: _canvas()),
                      const SizedBox(width: 14),
                      SizedBox(width: 360, child: detail),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_state.running)
          TertiaryButton(
            onPressed: _cancelling ? null : _cancel,
            child: Text(
              _cancelling
                  ? _tx('workflows.run_cancelling')
                  : _tx('workflows.run_cancel_btn'),
            ),
          ),
        if (_state.running)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _tx('workflows.run_background_hint'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tx('common.close')),
        ),
      ],
    );
  }
}
