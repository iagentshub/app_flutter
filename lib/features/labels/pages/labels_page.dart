import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/workflows/workflow_models.dart';
import '../../agents/repositories/agents_repository.dart';
import '../../knowledge/repositories/skills_repository.dart';
import '../../workflows/repositories/workflows_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/filter_button.dart';
import '../../../shared/widgets/label_chips_row.dart';

/// Vista unificada de un recurso propio (agente/skill/workflow) para el
/// buscador por labels — Knowledge queda fuera porque el backend todavía no
/// le asocia labels (no existe columna `labels` para ese tipo).
class _LabeledItem {
  const _LabeledItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.labels,
    required this.shared,
  });

  final String id;
  final String name;
  final String description;
  final String type;
  final List<String> labels;
  final bool shared;
}

const _kBlockingLabels = {'draft', 'quarantine', 'archived', 'delete'};

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

class _LabelsPageState extends State<LabelsPage> {
  late final AgentsRepository _agentsRepository;
  late final SkillsRepository _skillsRepository;
  late final WorkflowsRepository _workflowsRepository;
  late final TranslatedTexts _t;
  List<_LabeledItem> _all = const [];
  bool _loading = true;
  String? _error;
  String _selectedType = 'all';
  String _selectedLabel = '';

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _agentsRepository = AgentsRepository(apiClient: widget.apiClient);
    _skillsRepository = SkillsRepository(apiClient: widget.apiClient);
    _workflowsRepository = WorkflowsRepository(apiClient: widget.apiClient);
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
      ]);
      final agents = results[0] as List<AgentItem>;
      final skills = results[1] as List<SkillItem>;
      final workflows = results[2] as List<WorkflowItem>;

      final items = <_LabeledItem>[
        for (final a in agents)
          _LabeledItem(
            id: a.id,
            name: a.name,
            description: a.description,
            type: 'agent',
            labels: a.labels,
            shared: a.shared,
          ),
        for (final s in skills)
          _LabeledItem(
            id: s.id,
            name: s.name,
            description: s.description,
            type: 'skill',
            labels: s.labels,
            shared: s.shared,
          ),
        for (final w in workflows)
          _LabeledItem(
            id: w.id,
            name: w.name,
            description: w.description,
            type: 'workflow',
            labels: w.labels,
            shared: w.shared,
          ),
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

  List<_LabeledItem> get _filtered {
    return _all.where((item) {
      if (_selectedType != 'all' && item.type != _selectedType) return false;
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
      value: 'workflow',
      child: Text(_tx('explore.type_workflows', 'Workflows')),
    ),
  ];

  void _openFiltersDialog() {
    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => _onTypeChange('all'),
      buildFields: (setDialogState) => [
        DropdownButtonFormField<String>(
          initialValue: _selectedType,
          decoration: InputDecoration(
            labelText: _tx('labels.type_label', 'Tipo de recurso'),
          ),
          items: _typeOptions,
          onChanged: (value) {
            if (value == null) return;
            _onTypeChange(value);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    _tx('labels.error_title', 'Error cargando Labels'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loadBase,
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

    final labelCounts = _labelCounts();
    final labels = labelCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final filtered = _filtered;

    return Column(
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
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
                      TextButton.icon(
                        onPressed: () => setState(() => _selectedLabel = ''),
                        icon: const Icon(Icons.clear_all, size: 18),
                        label: Text(_tx('labels.clear', 'Limpiar')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadBase,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildCatalog(),
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
                                final selected = _selectedLabel == entry.key;
                                return ChoiceChip(
                                  label: Text(
                                    '${_tx('labels.${entry.key}', entry.key)} (${entry.value})',
                                  ),
                                  selected: selected,
                                  onSelected: (_) =>
                                      _applyFilter(selected ? '' : entry.key),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            '${_tx('labels.resources', 'Recursos')}: ${filtered.length}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          if (filtered.isEmpty)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  _tx(
                                    'labels.empty_resources',
                                    'No hay recursos para este label/filtro.',
                                  ),
                                ),
                              ),
                            )
                          else
                            ...filtered.map(_buildItemCard),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildItemCard(_LabeledItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showMessage(
          item.description.isEmpty
              ? _tx('labels.no_description', 'Sin descripción')
              : item.description,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _itemTypeLabel(item.type),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (item.shared) ...[
                    const SizedBox(width: 8),
                    Text(
                      '· ${_tx('labels.shared_badge', 'Compartido')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              if (item.labels.isNotEmpty) ...[
                const SizedBox(height: 8),
                LabelChipsRow(labels: item.labels),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCatalog() {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            _tx('labels.catalog_title', 'Catálogo de etiquetas'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              _tx(
                'labels.catalog_intro',
                'Las etiquetas definen el estado y comportamiento de tus recursos. '
                    'Cada recurso tiene siempre al menos una etiqueta de visibilidad.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final group in kLabelGroups) ...[
              Text(
                _tx(group.titleKey, group.fallbackTitle),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                group.exclusive
                    ? _tx(
                        'labels.exclusive_hint',
                        'Exclusivas (solo una activa)',
                      )
                    : _tx('labels.multi_hint', 'Multi-selección'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              for (final key in group.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCatalogLabelCard(key),
                ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCatalogLabelCard(String key) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CircleAvatar(radius: 5, backgroundColor: labelColor(key)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tx('labels.$key', key),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _tx('labels.desc_$key', ''),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_kBlockingLabels.contains(key) ||
                    key == 'deprecated' ||
                    key == 'private') ...[
                  const SizedBox(height: 6),
                  _buildBehaviorChip(key),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorChip(String key) {
    late final String label;
    late final Color color;
    if (_kBlockingLabels.contains(key)) {
      label = _tx('labels.behavior_blocks', 'Bloquea el recurso');
      color = Colors.red.shade700;
    } else if (key == 'deprecated') {
      label = _tx('labels.behavior_warns', 'Aviso visual');
      color = Colors.amber.shade800;
    } else {
      label = _tx('labels.behavior_default', 'Por defecto');
      color = Theme.of(context).colorScheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
