import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../app/router/router.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../models/explore/explore_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/action_result.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/explore_search_toolbar.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../manager/repositories/manager_repository.dart';
import '../controllers/explore_controller.dart';
import '../repositories/explore_repository.dart';

part '../cards/explore_resource_card.dart';
part '../cards/explore_user_card.dart';
part '../dialogs/preview_dialog.dart';
part '../widgets/explore_collection_views.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage>
    with SingleTickerProviderStateMixin, StateMessaging {
  late final ExploreController _controller;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _controller = ExploreController(
      repository: ExploreRepository(apiClient: widget.apiClient),
      managerRepository: ManagerRepository(apiClient: widget.apiClient),
      sessionController: widget.sessionController,
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

  String? get _token => widget.sessionController.gaToken;

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
      .where((l) => l != 'public' && l != 'private')
      .toList();

  static const _labelKeys = {
    'production': 'label_production',
    'staging': 'label_staging',
    'development': 'label_development',
    'test': 'label_test',
    'favorite': 'label_favorite',
    'draft': 'label_draft',
    'review': 'label_review',
    'deprecated': 'label_deprecated',
    'quarantine': 'label_quarantine',
    'archived': 'label_archived',
    'delete': 'label_delete',
  };

  /// Traduce el nombre de una label ("favorite", "draft"...) al idioma del sistema.
  String _labelChipLabel(String label) {
    final key = _labelKeys[label];
    if (key == null) return label;
    return _tx('explore.$key', label);
  }

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
      onClear: _controller.clearSecondaryFilters,
      buildFields: (setDialogState) => [
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
        Text(
          _tx('explore.label_label', 'Label'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _explorableLabelKeys.map((l) {
            return FilterChip(
              label: Text(_labelChipLabel(l)),
              selected: _controller.hasLabel(l),
              onSelected: (value) {
                _controller.toggleLabel(l, selected: value);
                setDialogState(() {});
              },
            );
          }).toList(),
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
