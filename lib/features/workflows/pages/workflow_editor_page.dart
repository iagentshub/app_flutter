import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../agents/repositories/agents_repository.dart';
import '../../connections/repositories/connections_repository.dart';
import '../../executions/controllers/resource_executions_controller.dart';
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
part '../widgets/workflow_editor_inspector.dart';
part 'workflow_editor_graph_actions.dart';
part 'workflow_editor_resources.dart';
part '../widgets/workflow_editor_settings_panel.dart';

/// Suelo de altura del lienzo en escritorio.
///
/// Por debajo de esto el `fitToView` del editor de nodos encoge las tarjetas
/// —260x140 cada una— hasta que dejan de leerse, que es peor que recortar el
/// diagrama y dejar que el usuario lo desplace.
const double _altoMinimoLienzo = 420;

class WorkflowEditorPage extends StatefulWidget {
  const WorkflowEditorPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    this.workflowRunsController,
    this.executionStateController,
    this.initial,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;
  final WorkflowRunsController? workflowRunsController;
  final ResourceExecutionsController? executionStateController;
  final Map<String, dynamic>? initial;

  @override
  State<WorkflowEditorPage> createState() => _WorkflowEditorPageState();
}

class _WorkflowEditorPageState extends State<WorkflowEditorPage>
    with SingleTickerProviderStateMixin {
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
  late final TabController _inspectorTabs;

  List<AgentItem> _agents = const [];
  List<ConnectionItem> _llmOrchestrations = const [];
  bool _loadingAgents = true;
  String? _error;
  late final WorkflowRunsController _workflowRuns;
  late final bool _ownsWorkflowRuns;
  late final ResourceExecutionsController _executionState;
  late final bool _ownsExecutionState;

  String _tx(String path) => _t.text(path);

  void _refresh(VoidCallback update) {
    setState(() {
      update();
      _issues = validateWorkflowGraph(_steps);
    });
  }

  @override
  void initState() {
    super.initState();
    _inspectorTabs = TabController(length: 3, vsync: this);
    _ownsWorkflowRuns = widget.workflowRunsController == null;
    _workflowRuns =
        widget.workflowRunsController ??
        WorkflowRunsController(
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
          autoStart: false,
        );
    _ownsExecutionState = widget.executionStateController == null;
    _executionState =
        widget.executionStateController ??
        ResourceExecutionsController(
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
          autoStart: false,
        );
    _executionState.addListener(_onExecutionStateChanged);
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

  void _onExecutionStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _executionState.removeListener(_onExecutionStateChanged);
    if (_ownsExecutionState) _executionState.dispose();
    if (_ownsWorkflowRuns) _workflowRuns.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _inspectorTabs.dispose();
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
      title: _tx('workflow_editor.unsaved_title'),
      message: _tx('workflow_editor.unsaved_body'),
      cancelLabel: _tx('workflow_editor.keep_editing'),
      confirmLabel: _tx('workflow_editor.discard_btn'),
      destructive: true,
    );
    if (discard && mounted) Navigator.of(context).pop();
  }

  Future<void> _testRun() async {
    final id = _workflowId;
    if (id == null || id.isEmpty || _token == null || _token!.isEmpty) return;
    final name = _nameController.text.trim();

    final input = await showAppDialog<String>(
      context: context,
      builder: (context) => RunWorkflowDialog(workflowName: name, tx: _tx),
    );
    if (input == null || input.trim().isEmpty || !mounted) return;

    final run = await _workflowRuns.startRun(
      workflowId: id,
      input: input.trim(),
    );
    if (!mounted) return;
    await showAppDialog<void>(
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

  Widget _buildCanvas() => WorkflowVisualCanvas(
    steps: _steps,
    agents: _agents,
    selectedStepId: _selectedStepId,
    issueNodeIds: {
      for (final issue in _issues)
        if (issue.nodeId != null) issue.nodeId!,
    },
    onStepSelected: _selectStep,
    onStepMoved: _moveStep,
    onStepDeleted: _removeStepById,
    onConnectionCreated: _createConnection,
    onConnectionDeleted: _deleteConnection,
    canCreateConnection: _canCreateConnection,
    fitTooltip: _tx('workflow_editor.fit_view'),
    zoomInTooltip: _tx('workflow_editor.zoom_in'),
    zoomOutTooltip: _tx('workflow_editor.zoom_out'),
    inputLabel: _tx('workflow_editor.input_port'),
    outputLabel: _tx('workflow_editor.output_port'),
    missingAgentLabel: _tx('workflow_editor.no_agent'),
    agentKindLabel: _tx('workflow_editor.kind_agent'),
    evaluatorKindLabel: _tx('workflow_editor.kind_evaluator'),
    loopLabel: _tx('workflow_editor.loop_label'),
    invalidConnectionMessage: _tx('workflow_editor.invalid_connection'),
  );

  Widget _buildWorkspace() {
    final canvas = _buildCanvas();
    final colors = Theme.of(context).colorScheme;
    final inspector = Container(
      key: const ValueKey('workflow-editor-inspector'),
      padding: const EdgeInsets.all(16),
      color: colors.surfaceContainerLow,
      child: Column(
        children: [
          TabBar(
            key: const ValueKey('workflow-inspector-tabs'),
            controller: _inspectorTabs,
            tabs: [
              Tab(text: _tx('workflow_editor.panel_step')),
              Tab(text: _tx('workflow_editor.panel_settings')),
              Tab(text: _tx('workflow_editor.panel_issues')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _inspectorTabs,
              children: [
                KeyedSubtree(
                  key: const ValueKey('workflow-inspector-step'),
                  child: _buildInspector(),
                ),
                _buildSettingsPanel(),
                _buildIssuesInspector(),
              ],
            ),
          ),
        ],
      ),
    );

    final canvasPane = ColoredBox(
      key: const ValueKey('workflow-editor-canvas-pane'),
      color: colors.surfaceContainerLowest,
      child: Column(
        children: [
          WorkflowEditorToolbar(
            stepCount: _steps.length,
            connectionCount: _steps.connectionCount,
            issueCount: _issues.length,
            stepsLabel: _tx('workflows.steps_suffix'),
            connectionsLabel: _tx('workflows.connections_suffix'),
            issuesLabel: _tx('workflow_editor.issues_suffix'),
            autoLayoutLabel: _tx('workflow_editor.auto_layout'),
            onAutoLayout: _autoLayout,
            addLabel: _tx('workflow_editor.add_step_btn'),
            onAdd: _addStep,
            onIssuesPressed: _issues.isEmpty
                ? null
                : () => _inspectorTabs.animateTo(2),
          ),
          Divider(height: 1, color: colors.outlineVariant),
          Expanded(child: canvas),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 980) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // El lienzo no tenía suelo en ninguna parte de la cadena, y como
              // `fitToView` encoge los nodos hasta que quepan, una ventana baja
              // lo dejaba ilegible en vez de recortado.
              // El lienzo no tenía suelo en ninguna parte de la cadena, y como
              // `fitToView` encoge los nodos hasta que quepan, una ventana baja
              // lo dejaba ilegible en vez de recortado.
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: _altoMinimoLienzo,
                  ),
                  child: canvasPane,
                ),
              ),
              VerticalDivider(width: 1, color: colors.outlineVariant),
              SizedBox(width: 400, child: inspector),
            ],
          );
        }
        return Column(
          children: [
            Expanded(flex: 3, child: canvasPane),
            Divider(height: 1, color: colors.outlineVariant),
            Expanded(flex: 2, child: inspector),
          ],
        );
      },
    );
  }

  List<Widget> _appBarActions({required bool compact}) {
    final inProgress =
        _workflowId != null &&
        _executionState.isInProgress('workflow', _workflowId!);
    final canRun =
        _workflowId != null && _issues.isEmpty && !_isDirty && !inProgress;
    final runTooltip = inProgress
        ? _tx('common.in_progress')
        : canRun
        ? _tx('workflow_editor.test_run_btn')
        : _tx('workflow_editor.test_run_disabled');
    if (compact) {
      return [
        if (_workflowId != null)
          AppIconButton.outlined(
            onPressed: canRun ? _testRun : null,
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: runTooltip,
          ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: AppIconButton.filled(
            key: const ValueKey('workflow-save-mobile'),
            onPressed: _issues.isEmpty ? _save : null,
            icon: const Icon(Icons.check_rounded),
            tooltip: _tx('workflow_editor.save_btn'),
          ),
        ),
      ];
    }
    return [
      if (_workflowId != null)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Tooltip(
            message: runTooltip,
            child: SecondaryButton.icon(
              onPressed: canRun ? _testRun : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(_tx('workflow_editor.test_run_btn')),
            ),
          ),
        ),
      PrimaryButton.icon(
        onPressed: _issues.isEmpty ? _save : null,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: Text(_tx('workflow_editor.save_btn')),
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
          // En escritorio el nombre vive aquí, no en el formulario: es
          // obligatorio, y su error de validación tiene que verse pase lo que
          // pase con el panel de ajustes. En móvil se queda donde estaba, en
          // la pestaña de detalles.
          title: compact
              ? Text(
                  widget.initial == null
                      ? _tx('workflow_editor.title_new')
                      : _tx('workflow_editor.title_edit'),
                )
              : _buildTituloEditable(),
          actions: _appBarActions(compact: compact),
        ),
        body: _loadingAgents
            ? const Center(child: IAgentsLoadingMark())
            : compact
            ? _buildMobileEditor()
            : Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_error != null)
                      MaterialBanner(
                        content: Text(_error!),
                        actions: [
                          TertiaryButton(
                            onPressed: () => setState(() => _error = null),
                            child: Text(_tx('common.close')),
                          ),
                        ],
                      ),
                    Expanded(child: _buildWorkspace()),
                  ],
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
                    label: _tx('workflow_editor.mobile_details'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.account_tree_outlined),
                    label: _tx('workflow_editor.mobile_canvas'),
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.edit_note_outlined),
                    label: _tx('workflow_editor.mobile_step'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
