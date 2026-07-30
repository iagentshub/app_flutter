import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/workflows/workflow_models.dart';
import '../repositories/workflows_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/filter_button.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import 'workflow_editor_page.dart';

class WorkflowsPage extends StatefulWidget {
  const WorkflowsPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends State<WorkflowsPage> {
  late final WorkflowsRepository _repository;
  late final TranslatedTexts _t;
  List<WorkflowItem> _workflows = const [];
  bool _loading = true;
  String? _error;
  String _scope = 'all';

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  int get _activeFilterCount => _scope != 'all' ? 1 : 0;

  List<WorkflowItem> get _filteredWorkflows {
    if (_scope == 'all') return _workflows;
    return _workflows.where((item) => item.scope == _scope).toList();
  }

  void _openFiltersDialog() {
    final scopeOptions = [
      ('all', _tx('explore.option_all', 'Todas')),
      ('private', _tx('agents.scope_private', 'Privado')),
      ('public', _tx('agents.scope_public', 'Público')),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => setState(() => _scope = 'all'),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label', 'Visibilidad'),
          value: _scope,
          options: scopeOptions,
          onChanged: (v) {
            setState(() => _scope = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _repository = WorkflowsRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
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
          localeController: widget.localeController,
        ),
      ),
    );
    if (payload == null) return;
    await _saveWorkflow(payload);
  }

  Future<void> _openEditDialog(WorkflowItem item) async {
    if (item.shared) {
      _showMessage(
        _tx(
          'workflows.readonly_shared',
          'Este workflow es compartido y es de solo lectura',
        ),
      );
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
          localeController: widget.localeController,
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
      _showMessage(_tx('workflows.save_success', 'Workflow guardado'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('workflows.save_error', 'No se pudo guardar el workflow'),
        isError: true,
      );
    }
  }

  Future<void> _deleteWorkflow(WorkflowItem item) async {
    if (item.shared) {
      _showMessage(
        _tx(
          'workflows.readonly_shared_delete',
          'Este workflow es compartido y no se puede eliminar',
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('workflows.delete_dialog_title', 'Eliminar workflow')),
        content: Text(
          _tx(
            'workflows.delete_dialog_body',
            '¿Seguro que quieres eliminar "{{name}}"?',
          ).replaceAll('{{name}}', item.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tx('common.cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_tx('common.delete', 'Eliminar')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteWorkflow(token, item.id);
      _showMessage(_tx('workflows.delete_success', 'Workflow eliminado'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('workflows.delete_error', 'No se pudo eliminar el workflow'),
        isError: true,
      );
    }
  }

  Future<void> _runWorkflow(WorkflowItem item) async {
    final input = await showDialog<String>(
      context: context,
      builder: (context) =>
          _RunWorkflowDialog(workflowName: item.name, tx: _tx),
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
        tx: _tx,
        stream: _repository.streamRun(
          token,
          workflowId: item.id,
          input: input.trim(),
        ),
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
                  Text(
                    _tx(
                      'workflows.error_loading_title',
                      'Error cargando workflows',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry', 'Reintentar')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final filteredWorkflows = _filteredWorkflows;
    final toolbar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            IconButton.filled(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add),
              tooltip: _tx('workflows.new_workflow_tooltip', 'Nuevo workflow'),
            ),
            IconButton.outlined(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: _tx('workflows.refresh_tooltip', 'Actualizar'),
            ),
            FilterButton(
              activeCount: _activeFilterCount,
              tooltip: _tx('common.filters', 'Filtros'),
              onPressed: _openFiltersDialog,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${_tx('workflows.count_label', 'Workflows')}: ${filteredWorkflows.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                sliver: SliverToBoxAdapter(child: toolbar),
              ),
              if (filteredWorkflows.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverToBoxAdapter(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _tx(
                            'workflows.empty_list',
                            'No hay workflows todavía.',
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildWorkflowCard(filteredWorkflows[index]),
                      childCount: filteredWorkflows.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkflowCard(WorkflowItem item) {
    final meta = <String>[
      '${item.nodes.length} ${_tx('workflows.steps_suffix', 'pasos')}',
      '${item.edges.length} ${_tx('workflows.connections_suffix', 'conexiones')}',
    ];

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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(meta.join(' · ')),
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
                  ownerLabel: _tx('common.owner', 'Propietario'),
                  linkedLabel: _tx('common.linked', 'Enlazado'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _runWorkflow(item),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text(_tx('workflows.run_btn', 'Ejecutar')),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditDialog(item),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
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
}

class _RunWorkflowDialog extends StatefulWidget {
  const _RunWorkflowDialog({required this.workflowName, required this.tx});

  final String workflowName;
  final String Function(String path, String fallback) tx;

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
      title: Text(
        widget
            .tx('workflows.run_dialog_title', 'Ejecutar: {{name}}')
            .replaceAll('{{name}}', widget.workflowName),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 640),
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: _inputController,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: widget.tx(
                'workflows.run_input_label',
                'Input inicial',
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return widget.tx(
                  'workflows.run_input_required',
                  'Input obligatorio',
                );
              }
              return null;
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.tx('workflows.run_btn', 'Ejecutar')),
        ),
      ],
    );
  }
}

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
          if (type == 'workflow_done')
            _finalOutput = event['output']?.toString();
          if (type == 'error')
            _errorMessage =
                event['message']?.toString() ??
                widget.tx(
                  'workflows.error_running_generic',
                  'Error ejecutando workflow',
                );
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
        FilledButton(
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
