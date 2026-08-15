import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../models/explore/explore_models.dart';
import '../../../shared/graph/graph_dialog.dart';
import '../../../shared/graph/graph_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/explore_search_toolbar.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/multi_select_dropdown.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../manager/repositories/manager_repository.dart';
import '../controllers/explore_controller.dart';
import '../repositories/explore_repository.dart';
import 'official_pack_page.dart';

part '../cards/explore_official_pack_card.dart';
part '../cards/explore_resource_card.dart';
part '../cards/explore_user_card.dart';
part '../dialogs/preview_dialog.dart';
part '../widgets/explore_collection_views.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin, StateMessaging {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final ExploreController _controller;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _controller = ExploreController(
      repository: ExploreRepository(apiClient: _services.apiClient),
      managerRepository: ManagerRepository(apiClient: _services.apiClient),
      sessionController: _services.sessionController,
      tx: _tx,
    )..addListener(_onControllerChanged);
    _tabController = TabController(length: 2, vsync: this);
    _controller.load();
    _controller.loadUsers();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => _services.sessionController.gaToken;

  /// Ejecuta una acción del controller y muestra su mensaje, si lo hay.
  Future<void> _runAction(Future<ActionResult?> action) async {
    final result = await action;
    if (result == null) return;
    showMessage(result.message, isError: result.isError);
  }

  Future<void> _preview(ExploreItem item) => _runAction(
    _controller.preview(
      item,
      present: (payload) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) =>
              _PreviewDialog(title: item.name, jsonPayload: payload, tx: _tx),
        );
      },
    ),
  );

  Future<void> _showResourceGraph(ExploreItem item) => _runAction(
    _controller.showResourceGraph(
      item,
      present: (graph) => _presentGraph(
        title: item.name,
        nodes: graph.nodes,
        edges: graph.edges,
        rootId: graph.rootId,
      ),
    ),
  );

  Future<void> _showOfficialPackGraph(ExploreOfficialPack pack) => _runAction(
    _controller.showOfficialPackGraph(
      pack,
      present: (graph) => _presentGraph(
        title: pack.name,
        nodes: graph.nodes,
        edges: graph.edges,
        rootId: graph.rootId,
      ),
    ),
  );

  Future<void> _presentGraph({
    required String title,
    required List<GraphNode> nodes,
    required List<GraphEdge> edges,
    required String rootId,
  }) async {
    if (!mounted) return;
    await showResourceGraphDialog(
      context: context,
      title: title,
      nodes: nodes,
      edges: edges,
      rootId: rootId,
      closeLabel: _tx('common.close', 'Cerrar'),
      searchHint: _tx('graph.search_hint', 'Buscar en el grafo...'),
      sortTooltip: _tx('graph.sort_tooltip', 'Ordenar'),
      sortHierarchyVerticalLabel: _tx(
        'graph.sort_hierarchy_vertical',
        'Jerárquico (arriba-abajo)',
      ),
      sortHierarchyHorizontalLabel: _tx(
        'graph.sort_hierarchy_horizontal',
        'Jerárquico (izquierda-derecha)',
      ),
      sortGalaxyLabel: _tx('graph.sort_galaxy', 'Galaxia'),
      showLabelsTooltip: _tx('graph.show_labels_tooltip', 'Mostrar nombres'),
      hideLabelsTooltip: _tx('graph.hide_labels_tooltip', 'Ocultar nombres'),
      quickViewDescriptionLabel: _tx(
        'graph.quick_view_description',
        'Descripción',
      ),
      quickViewNoDescriptionLabel: _tx(
        'graph.quick_view_no_description',
        'Sin descripción',
      ),
      quickViewConnectionsLabel: _tx(
        'graph.quick_view_connections',
        'Conexiones',
      ),
      quickViewNoConnectionsLabel: _tx(
        'graph.quick_view_no_connections',
        'Sin conexiones',
      ),
      emptyLabel: _tx('explore.graph_empty', 'El recurso no tiene relaciones'),
    );
  }

  void _openProfile(String username) {
    AppRouter.toPublicProfile(context, username);
  }

  // ── Traducción de las etiquetas de filtro y de las chips ──────────────

  List<(String, String)> get _typeOptions => [
    ('all', _tx('explore.type_all', 'Todos')),
    ('agent', _tx('explore.type_agents', 'Agentes')),
    ('skill', _tx('explore.type_skills', 'Skills')),
    ('prompt', _tx('explore.type_prompts', 'Prompts')),
    ('tool', _tx('explore.type_tools', 'Herramientas')),
    ('knowledge', _tx('explore.type_knowledge', 'Knowledge')),
    (
      'knowledge_pack',
      _tx('explore.type_knowledge_pack', 'Packs de conocimiento'),
    ),
    ('workflow', _tx('explore.type_workflows', 'Workflows')),
  ];

  static const _categoryKeys = {
    'Coding': 'category_coding',
    'Writing': 'category_writing',
    'Research': 'category_research',
    'Data': 'category_data',
    'DevOps': 'category_devops',
    'Support': 'category_support',
    'Education': 'category_education',
    'Productivity': 'category_productivity',
    'Marketing': 'category_marketing',
    'Finance': 'category_finance',
    'Other': 'category_other',
  };

  /// Traduce el tipo de recurso ("agent", "skill"...) al idioma del sistema,
  /// reutilizando las mismas etiquetas que el filtro de tipo.
  String _typeChipLabel(String type) {
    if (type == 'memory') return _tx('explore.type_memory', 'Memoria');
    if (type == 'official_pack') return _tx('explore.pack_badge', 'Pack');
    for (final option in _typeOptions) {
      if (option.$1 == type) return option.$2;
    }
    return type;
  }

  /// Traduce la categoría ("Coding", "Other"...) al idioma del sistema.
  String _categoryChipLabel(String category) {
    final key = _categoryKeys[category];
    if (key == null) return category;
    return _tx('explore.$key', category);
  }

  // En Explore todo lo listado es público (el backend solo devuelve
  // is_public=true), así que filtrar por "public"/"private" no aporta nada.
  static final _explorableLabelKeys = kLabelKeys
      .where((l) => l != 'public' && l != 'private' && !isLanguageLabel(l))
      .toList();

  /// Traduce el nombre de una label ("favorite", "draft"...) al idioma del sistema.
  String _labelChipLabel(String label) => _tx('labels.$label', label);

  List<ExploreTypeOption> get _publicExploreTypeOptions => [
    for (final option in _typeOptions.skip(1))
      ExploreTypeOption(
        value: option.$1,
        label: option.$2,
        icon: _publicTypeIcon(option.$1),
        color: labelColor(option.$1),
        count: _controller.typeCount(option.$1),
      ),
  ];

  IconData _publicTypeIcon(String type) => switch (type) {
    'agent' => Icons.smart_toy_outlined,
    'skill' => Icons.bolt_outlined,
    'prompt' => Icons.chat_bubble_outline,
    'tool' => Icons.build_outlined,
    'knowledge' => Icons.menu_book_outlined,
    'knowledge_pack' => Icons.inventory_2_outlined,
    'workflow' => Icons.account_tree_outlined,
    _ => Icons.category_outlined,
  };

  void _openFiltersDialog() {
    final optionAll = _tx('explore.option_all', 'Todas');
    final categoryOptions = [
      ('', optionAll),
      ..._controller.categoryOptions.map((c) => (c, _categoryChipLabel(c))),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: _controller.clearExploreFilters,
      buildFields: (setDialogState) => [
        Text(
          _tx('explore.official_display_label', 'Recursos oficiales'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            key: const Key('officialPackModeSelector'),
            segments: [
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: Text(_tx('explore.pack_mode', 'Packs')),
              ),
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.view_module_outlined, size: 16),
                label: Text(_tx('explore.individual_mode', 'Individuales')),
              ),
            ],
            selected: {_controller.officialPacksMode},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (values) {
              _controller.setOfficialPacksMode(values.first);
              setDialogState(() {});
            },
          ),
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        _dropdown(
          label: _tx('explore.category_label', 'Categoría'),
          value: _controller.category,
          options: categoryOptions,
          onChanged: (v) {
            _controller.setCategory(v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        MultiSelectDropdown<String>(
          key: const Key('exploreLanguageDropdown'),
          labelText: _tx('explore.language_label', 'Idioma'),
          tooltip: _tx('explore.language_filter_tooltip', 'Filtrar por idioma'),
          emptyLabel: optionAll,
          multipleSelectedLabel: (count) => _tx(
            'explore.languages_selected',
            '{count} idiomas',
          ).replaceAll('{count}', '$count'),
          options: [
            for (final language in kContentLanguageCodes)
              MultiSelectDropdownOption(
                value: language,
                label: contentLanguageLabel(_tx, language),
                color: labelColor(languageLabelKey(language)),
              ),
          ],
          selectedValues: _controller.selectedLanguages,
          onChanged: (values) {
            _controller.setLanguages(values);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        MultiSelectDropdown<String>(
          key: const Key('exploreLabelsDropdown'),
          labelText: _tx('explore.label_label', 'Etiqueta'),
          tooltip: _tx('explore.label_filter_tooltip', 'Filtrar por etiquetas'),
          emptyLabel: optionAll,
          multipleSelectedLabel: (count) => _tx(
            'explore.labels_selected',
            '{count} etiquetas',
          ).replaceAll('{count}', '$count'),
          options: [
            for (final label in _explorableLabelKeys)
              MultiSelectDropdownOption(
                value: label,
                label: _labelChipLabel(label),
                color: labelColor(label),
              ),
          ],
          selectedValues: _controller.selectedLabels,
          onChanged: (values) {
            _controller.setLabels(values);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: options
          .map(
            (opt) => DropdownMenuItem(
              value: opt.$1,
              child: Text(opt.$2, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (next) {
        if (next == null) return;
        onChanged(next);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: _tx('explore.tab_resources', 'Recursos')),
              Tab(text: _tx('explore.tab_users', 'Usuarios')),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildResourcesTab(), _buildUsersTab()],
          ),
        ),
      ],
    );
  }
}
