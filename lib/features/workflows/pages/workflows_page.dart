import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/workflows/workflow_models.dart';
import '../repositories/workflows_repository.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/action_icon_button.dart';
import 'workflow_editor_page.dart';

class WorkflowsPage extends StatefulWidget {
  const WorkflowsPage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends State<WorkflowsPage> {
  late final WorkflowsRepository _repository;
  List<WorkflowItem> _workflows = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = WorkflowsRepository(apiClient: widget.apiClient);
    _load();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final workflows = await _repository.listWorkflows(token);
      if (!mounted) return;
      setState(() {
        _workflows = workflows;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar workflows';
        _loading = false;
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => WorkflowEditorPage(
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
        ),
      ),
    );
    if (payload == null) return;
    await _saveWorkflow(payload);
  }

  Future<void> _openEditDialog(WorkflowItem item) async {
    if (item.shared) {
      _showMessage('Este workflow es compartido y es de solo lectura');
      return;
    }

    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _repository.getWorkflow(token, item.id);
    } catch (_) {}

    if (!mounted) return;
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => WorkflowEditorPage(
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
          initial: initial,
        ),
      ),
    );
    if (payload == null) return;
    payload['id'] = item.id;
    await _saveWorkflow(payload);
  }

  Future<void> _saveWorkflow(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.saveWorkflow(token, payload);
      _showMessage('Workflow guardado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo guardar el workflow', isError: true);
    }
  }

  Future<void> _deleteWorkflow(WorkflowItem item) async {
    if (item.shared) {
      _showMessage('Este workflow es compartido y no se puede eliminar');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar workflow'),
        content: Text('¿Seguro que quieres eliminar "${item.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteWorkflow(token, item.id);
      _showMessage('Workflow eliminado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar el workflow', isError: true);
    }
  }

  Future<void> _runWorkflow(WorkflowItem item) async {
    final input = await showDialog<String>(
      context: context,
      builder: (context) => _RunWorkflowDialog(workflowName: item.name),
    );
    if (input == null || input.trim().isEmpty) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _RunProgressDialog(
        workflowName: item.name,
        stream: _repository.streamRun(token, workflowId: item.id, input: input.trim()),
      ),
    );
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error cargando workflows', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo workflow'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Workflows: ${_workflows.length}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              if (_workflows.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay workflows todavía.'),
                  ),
                )
              else
                ..._workflows.map(_buildWorkflowCard),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowCard(WorkflowItem item) {
    final meta = <String>['${item.nodes.length} pasos', '${item.edges.length} conexiones'];
    if (item.labels.isNotEmpty) {
      meta.add('labels: ${item.labels.join(', ')}');
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                if (item.shared) _chip('shared'),
                _chip(item.scope),
              ],
            ),
            const SizedBox(height: 6),
            Text(meta.join(' · ')),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _runWorkflow(item),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Ejecutar'),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Editar',
                  onPressed: () => _openEditDialog(item),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Eliminar',
                  danger: true,
                  onPressed: () => _deleteWorkflow(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _RunWorkflowDialog extends StatefulWidget {
  const _RunWorkflowDialog({required this.workflowName});

  final String workflowName;

  @override
  State<_RunWorkflowDialog> createState() => _RunWorkflowDialogState();
}

class _RunWorkflowDialogState extends State<_RunWorkflowDialog> {
  final _formKey = GlobalKey<FormState>();
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_inputController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ejecutar: ${widget.workflowName}'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _inputController,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(labelText: 'Input inicial'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return 'Input obligatorio';
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Ejecutar')),
      ],
    );
  }
}

class _RunProgressDialog extends StatefulWidget {
  const _RunProgressDialog({required this.workflowName, required this.stream});

  final String workflowName;
  final Stream<Map<String, dynamic>> stream;

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
          if (type == 'workflow_done') _finalOutput = event['output']?.toString();
          if (type == 'error') _errorMessage = event['message']?.toString() ?? 'Error ejecutando workflow';
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        });
      },
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Error de conexión durante la ejecución';
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
    final agentName = event['agent_name']?.toString();
    final iteration = event['iteration'];
    switch (type) {
      case 'stage_started':
        return 'Ejecutando ${event['index']}/${event['total']}: ${agentName ?? 'agente'}';
      case 'stage_done':
        return 'Terminó ${agentName ?? 'agente'}';
      case 'evaluation_started':
        return 'Evaluando con ${agentName ?? 'agente'} (vuelta $iteration)';
      case 'evaluation_done':
        final approved = event['approved'] == true;
        return approved ? 'Evaluación aprobada' : 'Evaluación no aprobada, repitiendo';
      case 'loop_iteration_started':
        return 'Nueva vuelta del ciclo ($iteration)';
      case 'loop_limit_reached':
        return event['message']?.toString() ?? 'Se alcanzó el límite de vueltas del ciclo';
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
      title: Text('Ejecutando: ${widget.workflowName}'),
      content: SizedBox(
        width: 700,
        height: 460,
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
              Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600)),
            ],
            if (_finalOutput != null && _finalOutput!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              const Align(alignment: Alignment.centerLeft, child: Text('Salida final', style: TextStyle(fontWeight: FontWeight.bold))),
              const SizedBox(height: 6),
              SizedBox(
                height: 100,
                child: SingleChildScrollView(child: SelectableText(_finalOutput!)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: Text(_running ? 'Ejecutando…' : 'Cerrar'),
        ),
      ],
    );
  }
}
