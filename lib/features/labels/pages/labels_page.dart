import 'package:flutter/material.dart';

import '../../../models/agents/agent_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/tools/tool_models.dart';
import '../../../models/workflows/workflow_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/explore_search_toolbar.dart';
import '../../../shared/widgets/multi_select_dropdown.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../agents/repositories/agents_repository.dart';
import '../../knowledge/repositories/knowledge_repository.dart';
import '../../knowledge/repositories/prompts_repository.dart';
import '../../knowledge/repositories/skills_repository.dart';
import '../../knowledge/repositories/tools_repository.dart';
import '../../workflows/repositories/workflows_repository.dart';
import '../cards/label_catalog_card.dart';
import '../cards/labeled_item_card.dart';
import '../models/labeled_item.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({super.key});

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage>
    with SingleTickerProviderStateMixin, StateMessaging {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final AgentsRepository _agentsRepository;
  late final SkillsRepository _skillsRepository;
  late final PromptsRepository _promptsRepository;
  late final ToolsRepository _toolsRepository;
  late final KnowledgeRepository _knowledgeRepository;
  late final WorkflowsRepository _workflowsRepository;
  late final TranslatedTexts _t;
  late final TabController _tabController;
  late final TextEditingController _queryController;
  List<LabeledItem> _all = const [];
  bool _loading = true;
  String? _error;
  Set<String> _selectedTypes = {};
  Set<String> _selectedLabels = {};
  String _selectedOwnership = '';
  String _query = '';

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _agentsRepository = AgentsRepository(apiClient: _services.apiClient);
    _skillsRepository = SkillsRepository(apiClient: _services.apiClient);
    _promptsRepository = PromptsRepository(apiClient: _services.apiClient);
    _toolsRepository = ToolsRepository(apiClient: _services.apiClient);
    _knowledgeRepository = KnowledgeRepository(apiClient: _services.apiClient);
    _workflowsRepository = WorkflowsRepository(apiClient: _services.apiClient);
    _tabController = TabController(length: 2, vsync: this);
    _queryController = TextEditingController();
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _loadBase();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    _queryController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => _services.sessionController.gaToken;

  Future<void> _loadBase() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _agentsRepository.listAgents(token),
        _skillsRepository.listSkills(token),
        _workflowsRepository.listWorkflows(token),
        _promptsRepository.listPrompts(token),
        _toolsRepository.listTools(token),
        _knowledgeRepository.listItems(token),
      ]);
      final agents = results[0] as List<AgentItem>;
      final skills = results[1] as List<SkillItem>;
      final workflows = results[2] as List<WorkflowItem>;
      final prompts = results[3] as List<PromptItem>;
      final tools = results[4] as List<ToolItem>;
      final knowledge = results[5] as List<KnowledgeItem>;

      final items = <LabeledItem>[
        for (final a in agents) LabeledItem.fromResource(a, 'agent'),
        for (final s in skills) LabeledItem.fromResource(s, 'skill'),
        for (final w in workflows) LabeledItem.fromResource(w, 'workflow'),
        for (final p in prompts) LabeledItem.fromResource(p, 'prompt'),
        for (final tl in tools) LabeledItem.fromResource(tl, 'tool'),
        for (final item in knowledge)
          LabeledItem.fromResource(item, 'knowledge'),
      ];

      if (!mounted) return;
      setState(() {
        _all = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx('labels.error_generic', 'No se pudieron cargar labels');
        _loading = false;
      });
    }
  }

  List<LabeledItem> get _filtered {
    final query = _query.trim().toLowerCase();
    return _all.where((item) {
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(item.type)) {
        return false;
      }
      if (_selectedOwnership == 'owner' && item.shared) return false;
      if (_selectedOwnership == 'linked' && !item.shared) return false;
      if (!_selectedLabels.every(item.labels.contains)) {
        return false;
      }
      if (query.isNotEmpty) {
        final searchable = <String>[
          item.name,
          item.description,
          _itemTypeLabel(item.type),
          for (final label in item.labels) _tx('labels.$label', label),
        ].join(' ').toLowerCase();
        if (!searchable.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  int get _activeFilterCount =>
      (_selectedOwnership.isNotEmpty ? 1 : 0) + _selectedLabels.length;

  Map<String, int> _ownershipCounts() {
    final counts = {'owner': 0, 'linked': 0};
    for (final item in _all) {
      if (_selectedTypes.isNotEmpty && !_selectedTypes.contains(item.type)) {
        continue;
      }
      final key = item.shared ? 'linked' : 'owner';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  String _itemTypeLabel(String type) {
    switch (type) {
      case 'agent':
        return _tx('labels.item_type_agent', 'Agente');
      case 'skill':
        return _tx('labels.item_type_skill', 'Skill');
      case 'prompt':
        return _tx('labels.item_type_prompt', 'Prompt');
      case 'tool':
        return _tx('labels.item_type_tool', 'Herramienta');
      case 'workflow':
        return _tx('labels.item_type_workflow', 'Workflow');
      case 'knowledge':
        return _tx('labels.item_type_knowledge', 'Knowledge');
      default:
        return type;
    }
  }

  List<ExploreTypeOption> get _typeOptions {
    final counts = <String, int>{};
    for (final item in _all) {
      counts[item.type] = (counts[item.type] ?? 0) + 1;
    }
    return [
      _typeOption(
        'agent',
        _tx('explore.type_agents', 'Agentes'),
        Icons.smart_toy_outlined,
        counts,
      ),
      _typeOption(
        'skill',
        _tx('explore.type_skills', 'Skills'),
        Icons.bolt_outlined,
        counts,
      ),
      _typeOption(
        'prompt',
        _tx('explore.type_prompts', 'Prompts'),
        Icons.chat_bubble_outline,
        counts,
      ),
      _typeOption(
        'tool',
        _tx('explore.type_tools', 'Herramientas'),
        Icons.build_outlined,
        counts,
      ),
      _typeOption(
        'knowledge',
        _tx('explore.type_knowledge', 'Knowledge'),
        Icons.menu_book_outlined,
        counts,
      ),
      _typeOption(
        'workflow',
        _tx('explore.type_workflows', 'Workflows'),
        Icons.account_tree_outlined,
        counts,
      ),
    ];
  }

  ExploreTypeOption _typeOption(
    String value,
    String label,
    IconData icon,
    Map<String, int> counts,
  ) => ExploreTypeOption(
    value: value,
    label: label,
    icon: icon,
    color: labelColor(value),
    count: counts[value] ?? 0,
  );

  List<(String, String)> get _ownershipOptions {
    final counts = _ownershipCounts();
    return [
      ('', _tx('labels.all_ownership', 'Cualquier propiedad')),
      (
        'owner',
        '${_tx('labels.owner', 'Propietario')} (${counts['owner'] ?? 0})',
      ),
      (
        'linked',
        '${_tx('labels.linked', 'Enlazado')} (${counts['linked'] ?? 0})',
      ),
    ];
  }

  List<MultiSelectDropdownOption<String>> get _labelOptions {
    final counts = <String, int>{};
    for (final item in _all) {
      for (final label in item.labels) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort(
        (a, b) => _tx(
          'labels.${a.key}',
          a.key,
        ).compareTo(_tx('labels.${b.key}', b.key)),
      );
    return [
      for (final entry in entries)
        MultiSelectDropdownOption(
          value: entry.key,
          label: _tx('labels.${entry.key}', entry.key),
          color: labelColor(entry.key),
          count: entry.value,
        ),
    ];
  }

  void _clearFilters() {
    setState(() {
      _selectedOwnership = '';
      _selectedLabels = {};
    });
  }

  void _openFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: _clearFilters,
      buildFields: (setDialogState) => [
        FilterDropdown(
          key: ValueKey('labels-ownership-$_selectedOwnership'),
          label: _tx('labels.ownership_filter', 'Propiedad'),
          value: _selectedOwnership,
          options: _ownershipOptions,
          onChanged: (value) {
            setState(() => _selectedOwnership = value);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 16),
        MultiSelectDropdown<String>(
          key: const Key('labelsLabelDropdown'),
          labelText: _tx('labels.label_filter', 'Etiqueta'),
          tooltip: _tx('labels.selector_tooltip', 'Seleccionar etiquetas'),
          emptyLabel: _tx('labels.all_labels', 'Todas las etiquetas'),
          multipleSelectedLabel: (count) => _tx(
            'labels.selected_count',
            '{count} etiquetas seleccionadas',
          ).replaceAll('{count}', '$count'),
          options: _labelOptions,
          selectedValues: _selectedLabels,
          onChanged: (values) {
            setState(() => _selectedLabels = values);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  Widget _buildCatalogTab() {
    final groups = [kResourceTypeGroup, kOwnershipGroup, ...kLabelGroups];
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          sliver: SliverToBoxAdapter(child: LabelCatalogIntro(text: _tx)),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: ResponsiveSliverMasonryGrid(
            density: ResponsiveCardDensity.marketing,
            itemCount: groups.length,
            itemBuilder: (context, index) =>
                LabelGroupCard(group: groups[index], text: _tx),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchTab(BuildContext context) {
    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _loadBase,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: ExploreSearchToolbar(
                searchController: _queryController,
                searchHint: _tx(
                  'labels.search_hint',
                  'Buscar por nombre, descripción o etiqueta',
                ),
                onSearchChanged: (value) => setState(() => _query = value),
                typeOptions: _typeOptions,
                selectedTypes: _selectedTypes,
                allTypesLabel: _tx('explore.type_all', 'Todos'),
                typeFilterTooltip: _tx(
                  'labels.type_filter_tooltip',
                  'Filtrar por tipo de recurso',
                ),
                multipleTypesLabel: (count) => _tx(
                  'labels.types_selected',
                  '{count} tipos',
                ).replaceAll('{count}', '$count'),
                onTypesChanged: (values) =>
                    setState(() => _selectedTypes = values),
                selectorKey: const Key('labelsTypeDropdown'),
                actions: [
                  AppIconButton.outlined(
                    onPressed: _loadBase,
                    icon: const Icon(Icons.refresh),
                    tooltip: _tx('common.update', 'Actualizar'),
                  ),
                  FilterButton(
                    activeCount: _activeFilterCount,
                    tooltip: _tx('common.filters', 'Filtros'),
                    onPressed: _openFiltersDialog,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${_tx('labels.resources', 'Recursos')}: ${filtered.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (filtered.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: AsyncStatePanel.empty(
                  padding: EdgeInsets.zero,
                  icon: Icons.search_off,
                  title: _tx('labels.empty_title', 'Sin resultados'),
                  message: _tx(
                    'labels.empty_resources',
                    'No hay recursos para esta búsqueda o estos filtros.',
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return LabeledItemCard(
                    item: item,
                    typeLabel: _itemTypeLabel(item.type),
                    ownerLabel: _tx('common.owner', 'Propietario'),
                    linkedLabel: _tx('common.linked', 'Enlazado'),
                    labelText: (label) => _tx('labels.$label', label),
                    onTap: () => showMessage(
                      item.description.isEmpty
                          ? _tx('labels.no_description', 'Sin descripción')
                          : item.description,
                    ),
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
    if (_error != null) {
      return ListView(
        children: [
          AsyncStatePanel.error(
            title: _tx('labels.error_title', 'Error cargando Labels'),
            message: _error!,
            retryLabel: _tx('common.retry', 'Reintentar'),
            onRetry: _loadBase,
          ),
        ],
      );
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: _tx('labels.tab_catalog', 'Catálogo')),
            Tab(text: _tx('labels.tab_search', 'Buscar por etiqueta')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildCatalogTab(), _buildSearchTab(context)],
          ),
        ),
      ],
    );
  }
}
