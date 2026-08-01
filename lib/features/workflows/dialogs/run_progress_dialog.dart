part of '../pages/workflows_page.dart';

class _RunProgressDialog extends StatefulWidget {
  const _RunProgressDialog({
    required this.workflowName,
    required this.stream,
    required this.tx,
  });

  final String workflowName;
  final Stream<Map<String, dynamic>> stream;
  final String Function(String path, String fallback) tx;

  @override
  State<_RunProgressDialog> createState() => _RunProgressDialogState();
}

class _RunProgressDialogState extends State<_RunProgressDialog> {
  final List<({Map<String, dynamic> event, DateTime receivedAt})> _events = [];
  final _scrollController = ScrollController();
  bool _running = true;
  String? _finalOutput;
  String? _errorMessage;
  StreamSubscription<Map<String, dynamic>>? _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = widget.stream.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _events.add((event: event, receivedAt: DateTime.now()));
          final type = event['type']?.toString() ?? '';
          if (type == 'workflow_done') {
            _finalOutput = event['output']?.toString();
            _running = false;
          }
          if (type == 'error') {
            _errorMessage =
                event['message']?.toString() ??
                widget.tx(
                  'workflows.error_running_generic',
                  'Error ejecutando workflow',
                );
            _running = false;
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = _readError(error);
          _running = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _running = false);
      },
    );
  }

  String _readError(Object error) {
    if (error is ApiError) return error.message;
    final message = error.toString().trim();
    if (message.isNotEmpty && message != 'Exception') return message;
    return widget.tx(
      'workflows.error_connection',
      'Error de conexión durante la ejecución',
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  String _describe(Map<String, dynamic> event) {
    final type = event['type']?.toString() ?? '';
    final defaultAgent = widget.tx('workflows.default_agent_label', 'agente');
    final agentName = event['agent_name']?.toString() ?? defaultAgent;
    final iteration = event['iteration'];
    switch (type) {
      case 'stage_started':
        return widget
            .tx(
              'workflows.event_stage_started',
              'Ejecutando {{index}}/{{total}}: {{agent}}',
            )
            .replaceAll('{{index}}', '${event['index']}')
            .replaceAll('{{total}}', '${event['total']}')
            .replaceAll('{{agent}}', agentName);
      case 'stage_done':
        return widget
            .tx('workflows.event_stage_done', 'Terminó {{agent}}')
            .replaceAll('{{agent}}', agentName);
      case 'evaluation_started':
        return widget
            .tx(
              'workflows.event_evaluation_started',
              'Evaluando con {{agent}} (vuelta {{iteration}})',
            )
            .replaceAll('{{agent}}', agentName)
            .replaceAll('{{iteration}}', '$iteration');
      case 'evaluation_done':
        final approved = event['approved'] == true;
        return approved
            ? widget.tx(
                'workflows.event_evaluation_approved',
                'Evaluación aprobada',
              )
            : widget.tx(
                'workflows.event_evaluation_rejected',
                'Evaluación no aprobada, repitiendo',
              );
      case 'loop_iteration_started':
        return widget
            .tx(
              'workflows.event_loop_iteration',
              'Nueva vuelta del ciclo ({{iteration}})',
            )
            .replaceAll('{{iteration}}', '$iteration');
      case 'loop_limit_reached':
        return event['message']?.toString() ??
            widget.tx(
              'workflows.event_loop_limit',
              'Se alcanzó el límite de vueltas del ciclo',
            );
      case 'workflow_done':
        return widget.tx(
          'workflows.event_workflow_done',
          'Orquestación completada',
        );
      case 'error':
        return event['message']?.toString() ??
            widget.tx(
              'workflows.error_running_generic',
              'Error ejecutando workflow',
            );
      default:
        return event['message']?.toString() ?? type;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'stage_done':
        return Icons.check_circle_outline;
      case 'stage_started':
        return Icons.play_circle_outline_rounded;
      case 'evaluation_done':
        return Icons.fact_check_outlined;
      case 'evaluation_started':
        return Icons.rule_outlined;
      case 'loop_iteration_started':
        return Icons.replay;
      case 'loop_limit_reached':
        return Icons.warning_amber_outlined;
      case 'workflow_done':
        return Icons.task_alt_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      default:
        return Icons.notes_rounded;
    }
  }

  Color _colorFor(BuildContext context, String type) {
    final colors = Theme.of(context).colorScheme;
    return switch (type) {
      'stage_done' || 'workflow_done' => Colors.green.shade600,
      'error' || 'loop_limit_reached' => colors.error,
      'evaluation_started' || 'evaluation_done' => colors.tertiary,
      _ => colors.primary,
    };
  }

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}:'
      '${value.second.toString().padLeft(2, '0')}';

  Widget _eventCard(
    BuildContext context,
    ({Map<String, dynamic> event, DateTime receivedAt}) entry,
  ) {
    final colors = Theme.of(context).colorScheme;
    final event = entry.event;
    final type = event['type']?.toString() ?? '';
    final output = type == 'stage_done'
        ? event['output']?.toString().trim()
        : null;
    final accent = _colorFor(context, type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(_iconFor(type), size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _describe(event),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (output != null && output.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  SelectableText(
                    output,
                    maxLines: 5,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _clock(entry.receivedAt),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
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
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.tx(
                    'workflows.run_journal_title',
                    'Diario de ejecución',
                  ),
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_running) ...[
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 7),
                ],
                Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 760),
        height: dialogContentHeight(context, 520),
        child: Column(
          children: [
            Expanded(
              child: _events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 14),
                          Text(
                            widget.tx(
                              'workflows.run_waiting_first_event',
                              'Preparando la orquestación…',
                            ),
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      itemCount: _events.length,
                      itemBuilder: (context, index) =>
                          _eventCard(context, _events[index]),
                    ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SelectableText(
                  _errorMessage!,
                  style: TextStyle(
                    color: colors.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (_finalOutput != null && _finalOutput!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 150),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tx(
                          'workflows.final_output_title',
                          'Resultado final',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(_finalOutput!),
                    ],
                  ),
                ),
              ),
            ],
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
