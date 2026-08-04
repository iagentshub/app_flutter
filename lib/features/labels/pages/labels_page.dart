import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/async_state_panel.dart';

import '../../../core/network/api_client.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/workflows/workflow_models.dart';
import '../../agents/repositories/agents_repository.dart';
import '../../knowledge/repositories/prompts_repository.dart';
import '../../knowledge/repositories/skills_repository.dart';
import '../../workflows/repositories/workflows_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../cards/label_catalog_card.dart';
import '../cards/labeled_item_card.dart';
import '../dialogs/labels_filter_dialog.dart';
import '../models/labeled_item.dart';

class LabelsPage extends StatefulWidget {
  const LabelsPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<LabelsPage> createState() => _LabelsPageState();
}

class _LabelsPageState extends State<LabelsPage>
    with SingleTickerProviderStateMixin {
  late final AgentsRepository _agentsRepository;
  late final SkillsRepository _skillsRepository;
  late final PromptsRepository _promptsRepository;
  late final WorkflowsRepository _workflowsRepository;
  late final TranslatedTexts _t;
  late final TabController _tabController;
  List<LabeledItem> _all = const [];
  bool _loading = true;
  String? _error;
  String _selectedType = 'all';
  String _selectedLabel = '';
  String _selectedOwnership = '';

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _agentsRepository = AgentsRepository(apiClient: widget.apiClient);
    _skillsRepository = SkillsRepository(apiClient: widget.apiClient);
    _promptsRepository = PromptsRepository(apiClient: widget.apiClient);
    _workflowsRepository = WorkflowsRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: 2, vsync: this);
    _t = TranslatedTexts(
      localeController: widget.localeController,
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
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

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
      ]);
      final agents = results[0] as List<AgentItem>;
      final skills = results[1] as List<SkillItem>;
      final workflows = results[2] as List<WorkflowItem>;
      final prompts = results[3] as List<PromptItem>;

      final items = <LabeledItem>[
        for (final a in agents) LabeledItem.fromResource(a, 'agent'),
        for (final s in skills) LabeledItem.fromResource(s, 'skill'),
        for (final w in workflows) LabeledItem.fromResource(w, 'workflow'),
        for (final p in prompts) LabeledItem.fromResource(p, 'prompt'),
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

  void _onTypeChange(String value) {
    setState(() => _selectedType = value);
  }

  void _applyFilter(String label) {
    setState(() => _selectedLabel = label);
  }

  List<LabeledItem> get _filtered {
    return _all.where((item) {
      if (_selectedType != 'all' && item.type != _selectedType) return false;
      if (_selectedOwnership == 'owner' && item.shared) return false;
      if (_selectedOwnership == 'linked' && !item.shared) return false;
      if (_selectedLabel.isNotEmpty && !item.labels.contains(_selectedLabel)) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, int> _labelCounts() {
    final counts = <String, int>{};
    for (final item in _all) {
      if (_selectedType != 'all' && item.type != _selectedType) continue;
      for (final label in item.labels) {
        counts[label] = (counts[label] ?? 0) + 1;
      }
    }
    return counts;
  }

  Map<String, int> _ownershipCounts() {
    final counts = {'owner': 0, 'linked': 0};
    for (final item in _all) {
      if (_selectedType != 'all' && item.type != _selectedType) continue;
      final key = item.shared ? 'linked' : 'owner';
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  void _applyOwnership(String value) {
    setState(
      () => _selectedOwnership = _selectedOwnership == value ? '' : value,
    );
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _itemTypeLabel(String type) {
    switch (type) {
      case 'agent':
        return _tx('labels.item_type_agent', 'Agente');
      case 'skill':
        return _tx('labels.item_type_skill', 'Skill');
      case 'prompt':
        return _tx('labels.item_type_prompt', 'Prompt');
      case 'workflow':
        return _tx('labels.item_type_workflow', 'Workflow');
      default:
        return type;
    }
  }

  List<DropdownMenuItem<String>> get _typeOptions => [
    DropdownMenuItem(
      value: 'all',
      child: Text(_tx('explore.type_all', 'Todos')),
    ),
    DropdownMenuItem(
      value: 'agent',
      child: Text(_tx('explore.type_agents', 'Agentes')),
    ),
    DropdownMenuItem(
      value: 'skill',
      child: Text(_tx('explore.type_skills', 'Skills')),
    ),
    DropdownMenuItem(
      value: 'prompt',
      child: Text(_tx('explore.type_prompts', 'Prompts')),
    ),
    DropdownMenuItem(
      value: 'workflow',
      child: Text(_tx('explore.type_workflows', 'Workflows')),
    ),
  ];

  void _openFiltersDialog() {
    showLabelsFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      typeLabel: _tx('labels.type_label', 'Tipo de recurso'),
      selectedType: _selectedType,
      typeOptions: _typeOptions,
      onTypeChanged: _onTypeChange,
      onClear: () => _onTypeChange('all'),
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
    final labelCounts = _labelCounts();
    final labels = labelCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final ownershipCounts = _ownershipCounts();
    final filtered = _filtered;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterButton(
                    activeCount: _selectedType != 'all' ? 1 : 0,
                    tooltip: _tx('common.filters', 'Filtros'),
                    onPressed: _openFiltersDialog,
                  ),
                  Text(
                    '${_tx('labels.active_label', 'Label activo')}: ${_selectedLabel.isEmpty ? _tx('labels.none', '- ninguno -') : _tx('labels.$_selectedLabel', _selectedLabel)}',
                  ),
                  TertiaryButton.icon(
                    onPressed: () => setState(() {
                      _selectedLabel = '';
                      _selectedOwnership = '';
                    }),
                    icon: const Icon(Icons.clear_all, size: 18),
                    label: Text(_tx('labels.clear', 'Limpiar')),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadBase,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tx('labels.group_ownership', 'Propiedad'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: kOwnershipGroup.keys.map((key) {
                                  final selected = _selectedOwnership == key;
                                  final count = ownershipCounts[key] ?? 0;
                                  return ChoiceChip(
                                    label: Text(
                                      '${_tx('labels.$key', key)} ($count)',
                                    ),
                                    selected: selected,
                                    selectedColor: labelColor(
                                      key,
                                    ).withValues(alpha: 0.9),
                                    labelStyle: TextStyle(
                                      color: selected ? Colors.white : null,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : null,
                                    ),
                                    onSelected: (_) => _applyOwnership(key),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _tx('labels.detected', 'Etiquetas detectadas'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (labels.isEmpty)
                                Text(
                                  _tx(
                                    'labels.empty_detected',
                                    'No hay etiquetas disponibles',
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: labels.map((entry) {
                                    final selected =
                                        _selectedLabel == entry.key;
                                    return ChoiceChip(
                                      label: Text(
                                        '${_tx('labels.${entry.key}', entry.key)} (${entry.value})',
                                      ),
                                      selected: selected,
                                      onSelected: (_) => _applyFilter(
                                        selected ? '' : entry.key,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              const SizedBox(height: 16),
                              Text(
                                '${_tx('labels.resources', 'Recursos')}: ${filtered.length}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (filtered.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          sliver: SliverToBoxAdapter(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _tx(
                                    'labels.empty_resources',
                                    'No hay recursos para este label/filtro.',
                                  ),
                                ),
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
                                onTap: () => _showMessage(
                                  item.description.isEmpty
                                      ? _tx(
                                          'labels.no_description',
                                          'Sin descripción',
                                        )
                                      : item.description,
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
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
