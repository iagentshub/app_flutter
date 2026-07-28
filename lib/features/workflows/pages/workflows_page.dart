import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/workflows/workflow_models.dart';
import '../repositories/workflows_repository.dart';
import '../../../shared/state/session_controller.dart';

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
  String? _runningWorkflowId;

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
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _WorkflowFormDialog(),
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
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _WorkflowFormDialog(initial: initial),
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

    setState(() => _runningWorkflowId = item.id);
    try {
      final result = await _repository.runWorkflow(
        token,
        workflowId: item.id,
        input: input.trim(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _RunResultDialog(workflowName: item.name, result: result),
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo ejecutar el workflow', isError: true);
    } finally {
      if (mounted) setState(() => _runningWorkflowId = null);
    }
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
    final isRunning = _runningWorkflowId == item.id;
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isRunning ? null : () => _runWorkflow(item),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text(isRunning ? 'Ejecutando...' : 'Ejecutar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openEditDialog(item),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Editar'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteWorkflow(item),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Eliminar'),
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

class _WorkflowFormDialog extends StatefulWidget {
  const _WorkflowFormDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_WorkflowFormDialog> createState() => _WorkflowFormDialogState();
}

class _WorkflowFormDialogState extends State<_WorkflowFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _labelsController;
  late final TextEditingController _definitionController;
  String? _definitionError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?['name']?.toString() ?? '');
    _descriptionController = TextEditingController(text: initial?['description']?.toString() ?? '');
    final labels = (initial?['labels'] is List)
        ? (initial?['labels'] as List).map((item) => item.toString()).join(', ')
        : 'private';
    _labelsController = TextEditingController(text: labels);

    final rawDefinition = initial?['definition'];
    final pretty = const JsonEncoder.withIndent('  ').convert(
      rawDefinition is Map<String, dynamic>
          ? rawDefinition
          : {
              'nodes': [
                {
                  'id': 'step-1',
                  'agent_id': '',
                  'label': 'Paso 1',
                  'instruction': '',
                  'kind': 'agent',
                },
              ],
              'edges': [],
            },
    );
    _definitionController = TextEditingController(text: pretty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _labelsController.dispose();
    _definitionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final parsed = _parseDefinition(_definitionController.text);
    if (parsed == null) {
      setState(() => _definitionError = 'Definition JSON inválido o incompleto');
      return;
    }

    final labels = _labelsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'labels': labels.isEmpty ? ['private'] : labels,
      'definition': parsed,
    };
    if (widget.initial?['id'] != null) {
      payload['id'] = widget.initial!['id'];
    }
    Navigator.of(context).pop(payload);
  }

  Map<String, dynamic>? _parseDefinition(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final nodes = decoded['nodes'];
      final edges = decoded['edges'];
      if (nodes is! List || edges is! List || nodes.isEmpty) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo workflow' : 'Editar workflow'),
      content: SizedBox(
        width: 760,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Nombre obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _labelsController,
                decoration: const InputDecoration(labelText: 'Labels (coma separada)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _definitionController,
                minLines: 10,
                maxLines: 18,
                decoration: InputDecoration(
                  labelText: 'Definition (JSON)',
                  errorText: _definitionError,
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                onChanged: (_) {
                  if (_definitionError != null) {
                    setState(() => _definitionError = null);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
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

class _RunResultDialog extends StatelessWidget {
  const _RunResultDialog({required this.workflowName, required this.result});

  final String workflowName;
  final WorkflowRunResult result;

  @override
  Widget build(BuildContext context) {
    final title = result.ok ? 'Resultado' : 'Resultado con error';
    return AlertDialog(
      title: Text('$title: $workflowName'),
      content: SizedBox(
        width: 760,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (result.errorMessage != null) ...[
              Text(
                result.errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
            ],
            if (result.finalOutput != null && result.finalOutput!.trim().isNotEmpty) ...[
              const Text('Salida final', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              SelectableText(result.finalOutput!),
              const SizedBox(height: 12),
            ],
            const Text('Eventos', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (result.events.isEmpty)
              const Text('No se recibieron eventos')
            else
              ...result.events.map((event) {
                final type = event['type']?.toString() ?? 'event';
                final agentName = event['agent_name']?.toString();
                final message = event['message']?.toString();
                final subtitleParts = <String>[];
                if (agentName != null && agentName.isNotEmpty) subtitleParts.add(agentName);
                if (message != null && message.isNotEmpty) subtitleParts.add(message);
                if (event['iteration'] != null) subtitleParts.add('iteración ${event['iteration']}');
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chevron_right),
                  title: Text(type),
                  subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' · ')),
                );
              }),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
      ],
    );
  }
}
