import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../features/agents/repositories/agents_repository.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/workflows/workflow_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../cards/workflow_card.dart';
import '../dialogs/run_progress_dialog.dart';
import '../dialogs/run_workflow_dialog.dart';
import '../repositories/workflows_repository.dart';
import '../widgets/llm_orchestrations_panel.dart';
import 'workflow_editor_page.dart';

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
  late final TranslatedTexts _t;
  List<WorkflowItem> _workflows = const [];
  Map<String, AgentItem> _agentsById = const {};
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
    _repository = WorkflowsRepository(apiClient: _services.apiClient);
    _agentsRepository = AgentsRepository(apiClient: _services.apiClient);
    _t = TranslatedTexts(
      localeController: _services.localeController,
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

  String? get _token => _services.sessionController.gaToken;

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
        ),
      ),
    );
    if (payload == null) return;
    await _saveWorkflow(payload);
  }

  Future<void> _openEditDialog(WorkflowItem item) async {
    if (item.shared) {
      showMessage(
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
          apiClient: _services.apiClient,
          sessionController: _services.sessionController,
          localeController: _services.localeController,
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
      showMessage(_tx('workflows.save_success', 'Workflow guardado'));
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('workflows.save_error', 'No se pudo guardar el workflow'),
        isError: true,
      );
    }
  }

  Future<void> _toggleWorkflowActive(WorkflowItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final activate = !item.isActive;
    try {
      await _repository.setWorkflowActive(token, item.id, activate);
      showMessage(
        activate
            ? _tx('workflows.activated', 'Orquestación activada')
            : _tx('workflows.deactivated', 'Orquestación desactivada'),
      );
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('workflows.toggle_error', 'No se pudo cambiar el estado'),
        isError: true,
      );
    }
  }

  Future<void> _deleteWorkflow(WorkflowItem item) async {
    if (item.shared) {
      showMessage(
        _tx(
          'workflows.readonly_shared_delete',
          'Este workflow es compartido y no se puede eliminar',
        ),
      );
      return;
    }

    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('workflows.delete_dialog_title', 'Eliminar workflow'),
      message: _tx(
        'workflows.delete_dialog_body',
        '¿Seguro que quieres eliminar "{{name}}"?',
      ).replaceAll('{{name}}', item.name),
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      confirmLabel: _tx('common.delete', 'Eliminar'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteWorkflow(token, item.id);
      showMessage(_tx('workflows.delete_success', 'Workflow eliminado'));
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('workflows.delete_error', 'No se pudo eliminar el workflow'),
        isError: true,
      );
    }
  }

  Future<void> _runWorkflow(WorkflowItem item) async {
    final runIssue = _workflowRunIssue(item);
    if (runIssue != null) {
      showMessage(runIssue, isError: true);
      return;
    }

    final input = await showDialog<String>(
      context: context,
      builder: (context) => RunWorkflowDialog(workflowName: item.name, tx: _tx),
    );
    if (input == null || input.trim().isEmpty) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => RunProgressDialog(
        workflowName: item.name,
        definition: item.definition,
        agents: _agentsById.values.toList(),
        tx: _tx,
        stream: _repository.streamRun(
          token,
          workflowId: item.id,
          input: input.trim(),
        ),
      ),
    );
  }

  String? _workflowRunIssue(WorkflowItem item) {
    if (item.nodes.isEmpty) {
      return _tx(
        'workflows.run_error_no_steps',
        'Añade al menos un paso antes de ejecutar la orquestación.',
      );
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
        return _tx(
          'workflows.run_error_agent_missing',
          'El agente del paso “{{step}}” ya no está disponible. Edita el workflow y selecciona otro agente.',
        ).replaceAll(
          '{{step}}',
          displayStep.isEmpty
              ? _tx('workflows.default_agent_label', 'agente')
              : displayStep,
        );
      }
      if (agent.connectionId.isEmpty) {
        return _tx(
          'workflows.run_error_agent_connection',
          'El agente “{{agent}}” no tiene una conexión configurada.',
        ).replaceAll('{{agent}}', agent.name);
      }
    }
    return null;
  }

  Widget _buildAgentWorkflows(BuildContext context) {
    if (_loading) return const AsyncStatePanel.loading();
    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx(
              'workflows.error_loading_title',
              'Error cargando workflows',
            ),
            message: _error!,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _load,
          ),
        ],
      );
    }

    final filteredWorkflows = _filteredWorkflows;
    final toolbar = ResourceToolbar(
      actions: [
        AppIconButton.filled(
          onPressed: _openCreateDialog,
          icon: const Icon(Icons.add),
          tooltip: _tx('workflows.create_action', 'Crear workflow'),
        ),
        AppIconButton.outlined(
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
      summary: Text(
        '${_tx('workflows.count_label', 'Workflows')}: ${filteredWorkflows.length}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(child: toolbar),
          ),
          if (filteredWorkflows.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: filteredWorkflows.length,
                itemBuilder: (context, index) {
                  final item = filteredWorkflows[index];
                  return WorkflowCard(
                    item: item,
                    agentsById: _agentsById,
                    stepsLabel: _tx('workflows.steps_suffix', 'pasos'),
                    connectionsLabel: _tx(
                      'workflows.connections_suffix',
                      'conexiones',
                    ),
                    ownerLabel: _tx('common.owner', 'Propietario'),
                    linkedLabel: _tx('common.linked', 'Enlazado'),
                    runLabel: _tx('workflows.run_btn', 'Ejecutar'),
                    editTooltip: _tx('common.edit', 'Editar'),
                    deleteTooltip: _tx('common.delete', 'Eliminar'),
                    graphTooltip: _tx(
                      'workflows.graph_tooltip',
                      'Ver grafo de contenido',
                    ),
                    graphCloseLabel: _tx('common.close', 'Cerrar'),
                    graphEmptyLabel: _tx(
                      'workflows.graph_empty',
                      'Esta orquestación todavía no tiene pasos.',
                    ),
                    graphSearchHint: _tx(
                      'graph.search_hint',
                      'Buscar en el grafo...',
                    ),
                    graphSortTooltip: _tx('graph.sort_tooltip', 'Ordenar'),
                    graphSortHierarchyVerticalLabel: _tx(
                      'graph.sort_hierarchy_vertical',
                      'Jerárquico (arriba-abajo)',
                    ),
                    graphSortHierarchyHorizontalLabel: _tx(
                      'graph.sort_hierarchy_horizontal',
                      'Jerárquico (izquierda-derecha)',
                    ),
                    graphSortGalaxyLabel: _tx('graph.sort_galaxy', 'Galaxia'),
                    graphShowLabelsTooltip: _tx(
                      'graph.show_labels_tooltip',
                      'Mostrar nombres',
                    ),
                    graphHideLabelsTooltip: _tx(
                      'graph.hide_labels_tooltip',
                      'Ocultar nombres',
                    ),
                    graphQuickViewDescriptionLabel: _tx(
                      'graph.quick_view_description',
                      'Descripción',
                    ),
                    graphQuickViewNoDescriptionLabel: _tx(
                      'graph.quick_view_no_description',
                      'Sin descripción',
                    ),
                    graphQuickViewConnectionsLabel: _tx(
                      'graph.quick_view_connections',
                      'Conexiones',
                    ),
                    graphQuickViewNoConnectionsLabel: _tx(
                      'graph.quick_view_no_connections',
                      'Sin conexiones',
                    ),
                    inactiveLabel: _tx('common.inactive', 'Inactivo'),
                    activateTooltip: _tx('common.activate', 'Activar'),
                    deactivateTooltip: _tx('common.deactivate', 'Desactivar'),
                    onRun: () => _runWorkflow(item),
                    onEdit: () => _openEditDialog(item),
                    onDelete: () => _deleteWorkflow(item),
                    onToggleActive: item.readOnly
                        ? null
                        : () => _toggleWorkflowActive(item),
                  );
                },
              ),
            ),
        ],
      ),
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
                Tab(text: _tx('workflows.tab_agents', 'Agentes')),
                Tab(text: _tx('workflows.tab_llm_apis', 'APIs LLM')),
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
