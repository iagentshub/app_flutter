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
  final List<Map<String, dynamic>> _events = [];
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
        setState(() {
          _events.add(event);
          final type = event['type']?.toString() ?? '';
          if (type == 'workflow_done') {
            _finalOutput = event['output']?.toString();
          }
          if (type == 'error') {
            _errorMessage =
                event['message']?.toString() ??
                widget.tx(
                  'workflows.error_running_generic',
                  'Error ejecutando workflow',
                );
          }
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _errorMessage = widget.tx(
            'workflows.error_connection',
            'Error de conexión durante la ejecución',
          );
          _running = false;
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() => _running = false);
      },
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
      default:
        return type;
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'stage_done':
        return Icons.check_circle_outline;
      case 'evaluation_done':
        return Icons.fact_check_outlined;
      case 'loop_iteration_started':
        return Icons.replay;
      case 'loop_limit_reached':
        return Icons.warning_amber_outlined;
      default:
        return Icons.chevron_right;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget
            .tx('workflows.run_progress_title', 'Ejecutando: {{name}}')
            .replaceAll('{{name}}', widget.workflowName),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 700),
        height: dialogContentHeight(context, 460),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  final event = _events[index];
                  final type = event['type']?.toString() ?? '';
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_iconFor(type), size: 18),
                    title: Text(_describe(event)),
                  );
                },
              ),
            ),
            if (_running) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_finalOutput != null && _finalOutput!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.tx('workflows.final_output_title', 'Salida final'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(
                  child: SelectableText(_finalOutput!),
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
