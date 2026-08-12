import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../agents/repositories/agents_repository.dart';
import '../../connections/repositories/connections_repository.dart';
import '../cards/workflow_metadata_card.dart';
import '../controllers/workflow_runs_controller.dart';
import '../dialogs/run_progress_dialog.dart';
import '../dialogs/run_workflow_dialog.dart';
import '../models/workflow_graph_validation.dart';
import '../models/workflow_step_draft.dart';
import '../widgets/workflow_editor_toolbar.dart';
import '../widgets/workflow_issues_panel.dart';
import '../widgets/workflow_visual_canvas.dart';

part '../cards/workflow_step_editor_card.dart';
part '../widgets/workflow_editor_mobile.dart';
part 'workflow_editor_graph_actions.dart';
part 'workflow_editor_resources.dart';

class WorkflowEditorPage extends StatefulWidget {
  const WorkflowEditorPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    this.workflowRunsController,
    this.initial,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;
  final WorkflowRunsController? workflowRunsController;
  final Map<String, dynamic>? initial;

  @override
  State<WorkflowEditorPage> createState() => _WorkflowEditorPageState();
}

class _WorkflowEditorPageState extends State<WorkflowEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TranslatedTexts _t;
  late List<WorkflowStepDraft> _steps;
  late List<String> _labels;
  String? _llmOrchestrationConnectionId;
  late String _savedFingerprint;
  String? _selectedStepId;
  List<WorkflowIssue> _issues = const [];
  int _stepCounter = 0;
  int _mobileSection = 0;

  List<AgentItem> _agents = const [];
  List<ConnectionItem> _llmOrchestrations = const [];
  bool _loadingAgents = true;
  String? _error;
  late final WorkflowRunsController _workflowRuns;
  late final bool _ownsWorkflowRuns;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  void _refresh(VoidCallback update) {
    setState(() {
      update();
      _issues = validateWorkflowGraph(_steps);
    });
  }

  @override
  void initState() {
    super.initState();
    _ownsWorkflowRuns = widget.workflowRunsController == null;
    _workflowRuns =
        widget.workflowRunsController ??
        WorkflowRunsController(
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
          autoStart: false,
        );
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    final initial = widget.initial;
    _nameController = TextEditingController(
      text: initial?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: initial?['description']?.toString() ?? '',
    );
    _labels = (initial?['labels'] is List)
        ? (initial!['labels'] as List).map((item) => item.toString()).toList()
        : ['private'];
    if (_labels.isEmpty) _labels = ['private'];

    final definition = initial?['definition'];
    if (definition is Map<String, dynamic>) {
      final value = definition['llm_orchestration_connection_id']?.toString();
      _llmOrchestrationConnectionId = value == null || value.isEmpty
          ? null
          : value;
    }
    _steps = definition is Map<String, dynamic>
        ? stepsFromDefinition(definition)
        : const [];
    if (_steps.isEmpty) _steps = [_newStep()];
    _applyMissingPositions();
    _selectedStepId = _steps.first.id;
    _issues = validateWorkflowGraph(_steps);
    // Se calcula después de asignar posiciones para que abrir y cerrar sin
    // tocar nada no cuente como cambio pendiente.
    _savedFingerprint = _fingerprint();
    _loadResources();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_ownsWorkflowRuns) _workflowRuns.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  String? get _workflowId => widget.initial?['id']?.toString();

  WorkflowStepDraft _newStep() {
    _stepCounter += 1;
    return WorkflowStepDraft(
      id: 'step-${DateTime.now().millisecondsSinceEpoch}-$_stepCounter',
    );
  }

  // ── Estado del borrador ────────────────────────────────────────────────────

  String _fingerprint() => jsonEncode({
    'name': _nameController.text.trim(),
    'description': _descriptionController.text.trim(),
    'labels': [..._labels]..sort(),
    'definition': _definition(),
  });

  Map<String, dynamic> _definition() => {
    ...buildDefinition(_steps),
    if (_llmOrchestrationConnectionId != null)
      'llm_orchestration_connection_id': _llmOrchestrationConnectionId,
  };

  bool get _isDirty => _fingerprint() != _savedFingerprint;

  Map<String, dynamic> _payload() {
    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'labels': _labels.isEmpty ? ['private'] : _labels,
      'definition': _definition(),
    };
    final id = _workflowId;
    if (id != null) payload['id'] = id;
    return payload;
  }

  /// Coloca los pasos que aún no tienen posición siguiendo el flujo.
  void _applyMissingPositions() {
    final positions = layeredLayout(_steps);
    for (final step in _steps) {
      if (step.positionX != null && step.positionY != null) continue;
      final position = positions[step.id];
      if (position == null) continue;
      step.positionX = position.dx;
      step.positionY = position.dy;
    }
  }

  void _autoLayout() {
    final positions = layeredLayout(_steps);
    _refresh(() {
      for (final step in _steps) {
        final position = positions[step.id];
        if (position == null) continue;
        step.positionX = position.dx;
        step.positionY = position.dy;
      }
    });
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_issues.isNotEmpty) {
      final first = _issues.first;
      _refresh(() => _selectedStepId = first.nodeId ?? _selectedStepId);
      return;
    }
    _savedFingerprint = _fingerprint();
    Navigator.of(context).pop(_payload());
  }

  Future<void> _confirmDiscard() async {
    if (!_isDirty) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showConfirmActionDialog(
      context,
      title: _tx('workflow_editor.unsaved_title', 'Cambios sin guardar'),
      message: _tx(
        'workflow_editor.unsaved_body',
        'Si sales ahora perderás los cambios de esta orquestación.',
      ),
      cancelLabel: _tx('workflow_editor.keep_editing', 'Seguir editando'),
      confirmLabel: _tx('workflow_editor.discard_btn', 'Descartar'),
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  Future<void> _testRun() async {
    final id = _workflowId;
    if (id == null || id.isEmpty || _token == null || _token!.isEmpty) return;
    final name = _nameController.text.trim();

    final input = await showDialog<String>(
      context: context,
      builder: (context) => RunWorkflowDialog(workflowName: name, tx: _tx),
    );
    if (input == null || input.trim().isEmpty || !mounted) return;

    final run = await _workflowRuns.startRun(
      workflowId: id,
      input: input.trim(),
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RunProgressDialog(
        workflowName: run.workflowName,
        definition: run.definition,
        agents: run.agents.map((raw) => AgentItem(raw: raw)).toList(),
        tx: _tx,
        stream: _workflowRuns.events(run.id),
        onCancel: () async {
          await _workflowRuns.cancel(run.id);
        },
      ),
    );
  }

  // ── Composición ────────────────────────────────────────────────────────────

  Widget _buildInspector() {
    final index = _steps.indexWhere((step) => step.id == _selectedStepId);
    if (index < 0) {
      return Center(
        child: Text(
          _tx(
            'workflow_editor.select_node_hint',
            'Selecciona un nodo para editarlo',
          ),
        ),
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _tx(
                  'workflow_editor.inspector_title',
                  'Configuración del paso',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${index + 1}/${_steps.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildStepCard(index, key: ValueKey('inspector-${_steps[index].id}')),
      ],
    );
  }

  Widget _buildCanvas() => WorkflowVisualCanvas(
    steps: _steps,
    agents: _agents,
    selectedStepId: _selectedStepId,
    issueNodeIds: {
      for (final issue in _issues)
        if (issue.nodeId != null) issue.nodeId!,
    },
    onStepSelected: (id) => _refresh(() => _selectedStepId = id),
    onStepMoved: _moveStep,
    onStepDeleted: _removeStepById,
    onConnectionCreated: _createConnection,
    onConnectionDeleted: _deleteConnection,
    canCreateConnection: _canCreateConnection,
    fitTooltip: _tx('workflow_editor.fit_view', 'Encajar diagrama'),
    zoomInTooltip: _tx('workflow_editor.zoom_in', 'Acercar'),
    zoomOutTooltip: _tx('workflow_editor.zoom_out', 'Alejar'),
    connectionHint: _tx(
      'workflow_editor.visual_hint',
      'Arrastra desde la salida de un nodo hasta la entrada de otro',
    ),
    inputLabel: _tx('workflow_editor.input_port', 'Entrada'),
    outputLabel: _tx('workflow_editor.output_port', 'Salida'),
    missingAgentLabel: _tx('workflow_editor.no_agent', 'Sin agente'),
    agentKindLabel: _tx('workflow_editor.kind_agent', 'Agente'),
    evaluatorKindLabel: _tx('workflow_editor.kind_evaluator', 'Evaluador'),
    loopLabel: _tx('workflow_editor.loop_label', 'Bucle'),
    invalidConnectionMessage: _tx(
      'workflow_editor.invalid_connection',
      'La conexión crearía un ciclo o ya existe',
    ),
  );

  Widget _buildWorkspace() {
    final canvas = _buildCanvas();
    final colors = Theme.of(context).colorScheme;
    final inspector = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: _buildInspector(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 980) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: canvas),
              const SizedBox(width: 18),
              SizedBox(width: 400, child: inspector),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 3, child: canvas),
            const SizedBox(height: 16),
            Expanded(flex: 2, child: inspector),
          ],
        );
      },
    );
  }

  List<Widget> _appBarActions({required bool compact}) {
    final canRun = _workflowId != null && _issues.isEmpty && !_isDirty;
    if (compact) {
      return [
        if (_workflowId != null)
          AppIconButton.outlined(
            onPressed: canRun ? _testRun : null,
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: canRun
                ? _tx('workflow_editor.test_run_btn', 'Probar')
                : _tx(
                    'workflow_editor.test_run_disabled',
                    'Guarda los cambios para poder probar la orquestación',
                  ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AppIconButton.filled(
            key: const ValueKey('workflow-save-mobile'),
            onPressed: _issues.isEmpty ? _save : null,
            icon: const Icon(Icons.check_rounded),
            tooltip: _tx('workflow_editor.save_btn', 'Guardar'),
          ),
        ),
      ];
    }
    return [
      if (_workflowId != null)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: canRun
                ? _tx('workflow_editor.test_run_btn', 'Probar')
                : _tx(
                    'workflow_editor.test_run_disabled',
                    'Guarda los cambios para poder probar la orquestación',
                  ),
            child: SecondaryButton.icon(
              onPressed: canRun ? _testRun : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(_tx('workflow_editor.test_run_btn', 'Probar')),
            ),
          ),
        ),
      PrimaryButton.icon(
        onPressed: _issues.isEmpty ? _save : null,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: Text(_tx('workflow_editor.save_btn', 'Guardar')),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: colors.surfaceContainerLowest,
        appBar: AppBar(
          title: Text(
            widget.initial == null
                ? _tx('workflow_editor.title_new', 'Nuevo workflow')
                : _tx('workflow_editor.title_edit', 'Editar workflow'),
          ),
          actions: _appBarActions(compact: compact),
        ),
        body: _loadingAgents
            ? const Center(child: CircularProgressIndicator())
            : compact
            ? _buildMobileEditor()
            : Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      if (_error != null) ...[
                        MaterialBanner(
                          content: Text(_error!),
                          actions: [
                            TertiaryButton(
                              onPressed: () => setState(() => _error = null),
                              child: Text(_tx('common.close', 'Cerrar')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      WorkflowMetadataCard(
                        nameController: _nameController,
                        descriptionController: _descriptionController,
                        llmOrchestrations: _llmOrchestrations,
                        llmOrchestrationConnectionId:
                            _llmOrchestrationConnectionId,
                        onLlmOrchestrationChanged: (value) => _refresh(
                          () => _llmOrchestrationConnectionId = value,
                        ),
                        isPublic: _labels.contains('public'),
                        onChanged: () => setState(() {}),
                        onVisibilityChanged: (isPublic) => _refresh(() {
                          // Se conservan las etiquetas propias del usuario;
                          // solo cambia el par private/public.
                          _labels = [
                            for (final label in _labels)
                              if (label != 'private' && label != 'public')
                                label,
                            isPublic ? 'public' : 'private',
                          ];
                        }),
                        selectedLanguageLabels: _labels
                            .where(isLanguageLabel)
                            .toSet(),
                        onLanguageLabelsChanged: (next) => _refresh(() {
                          _labels = [
                            for (final label in _labels)
                              if (!isLanguageLabel(label)) label,
                            ...next,
                          ];
                        }),
                        tx: _tx,
                      ),
                      const SizedBox(height: 16),
                      WorkflowEditorToolbar(
                        title: _tx(
                          'workflow_editor.canvas_title',
                          'Lienzo de orquestación',
                        ),
                        subtitle: _tx(
                          'workflow_editor.canvas_subtitle',
                          'Diseña el flujo conectando agentes visualmente',
                        ),
                        stepCount: _steps.length,
                        connectionCount: _steps.connectionCount,
                        issueCount: _issues.length,
                        stepsLabel: _tx('workflows.steps_suffix', 'pasos'),
                        connectionsLabel: _tx(
                          'workflows.connections_suffix',
                          'conexiones',
                        ),
                        issuesLabel: _tx(
                          'workflow_editor.issues_suffix',
                          'problemas',
                        ),
                        autoLayoutLabel: _tx(
                          'workflow_editor.auto_layout',
                          'Auto-organizar',
                        ),
                        onAutoLayout: _autoLayout,
                        addLabel: _tx(
                          'workflow_editor.add_step_btn',
                          'Añadir paso',
                        ),
                        onAdd: _addStep,
                      ),
                      const SizedBox(height: 14),
                      WorkflowIssuesPanel(
                        issues: _issues,
                        title: _tx(
                          'workflow_editor.issues_title',
                          '{{n}} problemas impiden guardar',
                        ),
                        translate: _tx,
                        onSelectNode: (id) =>
                            _refresh(() => _selectedStepId = id),
                      ),
                      Expanded(child: _buildWorkspace()),
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: compact && !_loadingAgents
            ? NavigationBar(
                selectedIndex: _mobileSection,
                onDestinationSelected: (index) =>
                    setState(() => _mobileSection = index),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.tune_outlined),
                    label: _tx('workflow_editor.mobile_details', 'Detalles'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.account_tree_outlined),
                    label: _tx('workflow_editor.mobile_canvas', 'Diagrama'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.edit_note_outlined),
                    label: _tx('workflow_editor.mobile_step', 'Paso'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
