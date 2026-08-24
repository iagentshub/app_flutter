import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../features/agents/repositories/agents_repository.dart';
import '../../../features/connections/repositories/connections_repository.dart';
import '../../../features/executions/controllers/resource_executions_controller.dart';
import '../../../features/knowledge/repositories/knowledge_repository.dart';
import '../../../features/knowledge/repositories/prompts_repository.dart';
import '../../../features/knowledge/repositories/skills_repository.dart';
import '../../../features/knowledge/repositories/tools_repository.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/tools/tool_models.dart';
import '../../../models/workflows/workflow_models.dart';
import '../../../shared/graph/resource_graph_builder.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/iagents_async_view.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/resource_collection_view.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../../utils/i18n.dart';
import '../cards/workflow_card.dart';
import '../controllers/workflow_runs_controller.dart';
import '../dialogs/run_progress_dialog.dart';
import '../dialogs/run_workflow_dialog.dart';
import '../models/workflow_run.dart';
import '../repositories/workflows_repository.dart';
import '../widgets/llm_orchestrations_panel.dart';
import '../widgets/workflow_runs_panel.dart';
import 'workflow_editor_page.dart';

part 'workflows_run_history_actions.dart';

class WorkflowsPage extends StatefulWidget {
  const WorkflowsPage({super.key});

  @override
  State<WorkflowsPage> createState() => _WorkflowsPageState();
}

class _WorkflowsPageState extends State<WorkflowsPage> with StateMessaging {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final WorkflowsRepository _repository;
  late final AgentsRepository _agentsRepository;

  /// Catálogo de nombres del grafo, cargado la primera vez que alguien abre
  /// uno y reutilizado después. Cargarlo al entrar en la pantalla serían seis
  /// llamadas al backend por un grafo que la mayoría de las visitas no abre.
  Future<ResourceNames>? _graphNames;
  late final TranslatedTexts _t;
  late final WorkflowRunsController _workflowRuns;
  late final bool _ownsWorkflowRuns;
  late final ResourceExecutionsController _executionState;
  late final bool _ownsExecutionState;
  List<WorkflowItem> _workflows = const [];
  Map<String, AgentItem> _agentsById = const {};
  bool _loading = true;
  String? _error;
  String _scope = 'all';

  String _tx(String path) => _t.text(path);

  int get _activeFilterCount => _scope != 'all' ? 1 : 0;

  List<WorkflowItem> get _filteredWorkflows {
    if (_scope == 'all') return _workflows;
    return _workflows.where((item) => item.scope == _scope).toList();
  }

  void _openFiltersDialog() {
    final scopeOptions = [
      ('all', _tx('explore.option_all')),
      ('private', _tx('agents.scope_private')),
      ('public', _tx('agents.scope_public')),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () => setState(() => _scope = 'all'),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label'),
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
    _repository = WorkflowsRepository(apiClient: _services.apiClient);
    _agentsRepository = AgentsRepository(apiClient: _services.apiClient);
    _ownsWorkflowRuns = _services.workflowRunsController == null;
    _workflowRuns =
        _services.workflowRunsController ??
        WorkflowRunsController(
          apiClient: _services.apiClient,
          sessionController: _services.sessionController,
          autoStart: false,
        );
    _ownsExecutionState = _services.resourceExecutionsController == null;
    _executionState =
        _services.resourceExecutionsController ??
        ResourceExecutionsController(
          apiClient: _services.apiClient,
          sessionController: _services.sessionController,
          autoStart: false,
        );
    _executionState.addListener(_onExecutionStateChanged);
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  void _onExecutionStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    _executionState.removeListener(_onExecutionStateChanged);
    if (_ownsExecutionState) _executionState.dispose();
    if (_ownsWorkflowRuns) _workflowRuns.dispose();
    super.dispose();
  }

  String? get _token => _services.sessionController.gaToken;

  Future<ResourceNames> _loadGraphNames() {
    return _graphNames ??= () async {
      final token = _token;
      if (token == null || token.isEmpty) return const ResourceNames();
      final apiClient = _services.apiClient;
      try {
        final results = await Future.wait([
          SkillsRepository(apiClient: apiClient).listSkills(token),
          PromptsRepository(apiClient: apiClient).listPrompts(token),
          ToolsRepository(apiClient: apiClient).listTools(token),
          KnowledgeRepository(apiClient: apiClient).listItems(token),
          KnowledgeRepository(apiClient: apiClient).listPacks(token),
          ConnectionsRepository(apiClient: apiClient).listConnections(token),
        ]);
        return ResourceNames.fromCatalogs(
          skills: results[0] as List<SkillItem>,
          prompts: results[1] as List<PromptItem>,
          tools: results[2] as List<ToolItem>,
          knowledge: results[3] as List<KnowledgeItem>,
          packs: results[4] as List<KnowledgePack>,
          connections: results[5] as List<ConnectionItem>,
        );
      } on ApiError {
        // Un catálogo que no llega degrada a ids crudos, que es lo que se
        // veía antes: no es motivo para dejar sin grafo al usuario.
        _graphNames = null;
        return const ResourceNames();
      }
    }();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = tr('common.no_session');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final workflows = await _repository.listWorkflows(
        token,
        includeInactive: true,
      );
      final agents = await _agentsRepository
          .listAgents(token)
          .catchError((_) => <AgentItem>[]);
      if (!mounted) return;
      setState(() {
        _workflows = workflows;
        _agentsById = {for (final agent in agents) agent.id: agent};
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
          apiClient: _services.apiClient,
          sessionController: _services.sessionController,
          localeController: _services.localeController,
          workflowRunsController: _workflowRuns,
          executionStateController: _executionState,
        ),
      ),
    );
    if (payload == null) return;
    await _saveWorkflow(payload);
  }

  Future<void> _openEditDialog(WorkflowItem item) async {
    if (item.shared) {
      showMessage(_tx('workflows.readonly_shared'));
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
          apiClient: _services.apiClient,
          sessionController: _services.sessionController,
          localeController: _services.localeController,
          workflowRunsController: _workflowRuns,
          executionStateController: _executionState,
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
      showMessage(_tx('workflows.save_success'));
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('workflows.save_error'), isError: true);
    }
  }

  Future<void> _toggleWorkflowActive(WorkflowItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final activate = !item.isActive;
    try {
      await _repository.setWorkflowActive(token, item.id, activate);
      showMessage(
        activate ? _tx('workflows.activated') : _tx('workflows.deactivated'),
      );
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('workflows.toggle_error'), isError: true);
    }
  }

  Future<void> _deleteWorkflow(WorkflowItem item) async {
    if (item.shared) {
      showMessage(_tx('workflows.readonly_shared_delete'));
      return;
    }

    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('workflows.delete_dialog_title'),
      message: _tx('workflows.delete_dialog_body')
          .replaceAll('{{name}}', item.name),
      cancelLabel: _tx('common.cancel'),
      confirmLabel: _tx('common.delete'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteWorkflow(token, item.id);
      showMessage(_tx('workflows.delete_success'));
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('workflows.delete_error'), isError: true);
    }
  }

  Future<void> _runWorkflow(WorkflowItem item) async {
    final runIssue = _workflowRunIssue(item);
    if (runIssue != null) {
      showMessage(runIssue, isError: true);
      return;
    }

    final input = await showAppDialog<String>(
      context: context,
      builder: (context) => RunWorkflowDialog(workflowName: item.name, tx: _tx),
    );
    if (input == null || input.trim().isEmpty) return;

    if (!mounted) return;
    try {
      final run = await _workflowRuns.startRun(
        workflowId: item.id,
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
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('workflows.run_start_error'), isError: true);
    }
  }

  String? _workflowRunIssue(WorkflowItem item) {
    if (!item.isActive) {
      return _tx('workflows.run_error_inactive');
    }
    if (item.nodes.isEmpty) {
      return _tx('workflows.run_error_no_steps');
    }

    for (final rawNode in item.nodes) {
      if (rawNode is! Map) continue;
      final agentId = rawNode['agent_id']?.toString() ?? '';
      final stepLabel = rawNode['label']?.toString().trim();
      final displayStep = stepLabel == null || stepLabel.isEmpty
          ? agentId
          : stepLabel;
      final agent = _agentsById[agentId];
      if (agent == null) {
        return _tx('workflows.run_error_agent_missing').replaceAll(
          '{{step}}',
          displayStep.isEmpty
              ? _tx('workflows.default_agent_label')
              : displayStep,
        );
      }
      if (!agent.isActive) {
        return _tx('workflows.run_error_agent_inactive')
            .replaceAll('{{agent}}', agent.name);
      }
      if (agent.connectionId.isEmpty &&
          item.llmOrchestrationConnectionId.isEmpty) {
        return _tx('workflows.run_error_agent_connection')
            .replaceAll('{{agent}}', agent.name);
      }
    }
    return null;
  }

  Widget _buildAgentWorkflows(BuildContext context) {
    final filteredWorkflows = _filteredWorkflows;
    final toolbar = ResourceToolbar(
      actions: [
        AppIconButton.filled(
          onPressed: _openCreateDialog,
          icon: const Icon(Icons.add),
          tooltip: _tx('workflows.create_action'),
        ),
        WorkflowRunsButton(
          controller: _workflowRuns,
          onPressed: _openRunsPanel,
          tooltip: _tx('workflows.run_history_title'),
        ),
        AppIconButton.outlined(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: _tx('workflows.refresh_tooltip'),
        ),
        FilterButton(
          activeCount: _activeFilterCount,
          tooltip: _tx('common.filters'),
          onPressed: _openFiltersDialog,
        ),
      ],
      summary: Text(
        '${_tx('workflows.count_label')}: ${filteredWorkflows.length}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );

    final content = ResourceCollectionView(
      header: toolbar,
      onRefresh: _load,
      itemCount: filteredWorkflows.length,
      itemBuilder: (context, index) {
        final item = filteredWorkflows[index];
        return WorkflowCard(
          item: item,
          inProgress: _executionState.isInProgress('workflow', item.id),
          inProgressLabel: _tx('common.in_progress'),
          agentsById: _agentsById,
          graphNamesLoader: _loadGraphNames,
          stepsLabel: _tx('workflows.steps_suffix'),
          connectionsLabel: _tx('workflows.connections_suffix'),
          ownerLabel: _tx('common.owner'),
          linkedLabel: _tx('common.linked'),
          forkLabel: _tx('common.fork'),
          labelText: (label) => trOr('labels.$label', label),
          runLabel: _tx('workflows.run_btn'),
          editTooltip: _tx('common.edit'),
          deleteTooltip: _tx('common.delete'),
          graphTooltip: _tx('workflows.graph_tooltip'),
          graphCloseLabel: _tx('common.close'),
          graphEmptyLabel: _tx('workflows.graph_empty'),
          graphSearchHint: _tx('graph.search_hint'),
          graphSortTooltip: _tx('graph.sort_tooltip'),
          graphSortHierarchyVerticalLabel: _tx('graph.sort_hierarchy_vertical'),
          graphSortHierarchyHorizontalLabel: _tx(
            'graph.sort_hierarchy_horizontal',
          ),
          graphSortGalaxyLabel: _tx('graph.sort_galaxy'),
          graphShowLabelsTooltip: _tx('graph.show_labels_tooltip'),
          graphHideLabelsTooltip: _tx('graph.hide_labels_tooltip'),
          graphQuickViewDescriptionLabel: _tx('graph.quick_view_description'),
          graphQuickViewNoDescriptionLabel: _tx(
            'graph.quick_view_no_description',
          ),
          graphQuickViewConnectionsLabel: _tx('graph.quick_view_connections'),
          graphQuickViewNoConnectionsLabel: _tx(
            'graph.quick_view_no_connections',
          ),
          inactiveLabel: _tx('common.inactive'),
          activateTooltip: _tx('common.activate'),
          deactivateTooltip: _tx('common.deactivate'),
          onRun: () => _runWorkflow(item),
          onEdit: () => _openEditDialog(item),
          onDelete: () => _deleteWorkflow(item),
          onToggleActive: item.readOnly
              ? null
              : () => _toggleWorkflowActive(item),
        );
      },
    );
    return IAgentsAsyncView(
      loading: _loading,
      localeController: _services.localeController,
      error: _error,
      errorTitle: _tx('workflows.error_loading_title'),
      retryLabel: _tx('common.retry'),
      onRetry: _load,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              tabs: [
                Tab(text: _tx('workflows.tab_agents')),
                Tab(text: _tx('workflows.tab_llm_apis')),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAgentWorkflows(context),
                LlmOrchestrationsPanel(
                  apiClient: _services.apiClient,
                  sessionController: _services.sessionController,
                  localeController: _services.localeController,
                  tx: _tx,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
