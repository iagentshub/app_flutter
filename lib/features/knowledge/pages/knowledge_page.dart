import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../features/memory/pages/memory_page.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../repositories/knowledge_repository.dart';
import '../repositories/prompts_repository.dart';
import '../repositories/skills_repository.dart';
import 'skill_builder_page.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_history_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';

part '../cards/knowledge_sections.dart';
part '../cards/prompt_sections.dart';
part '../controllers/knowledge_actions.dart';
part '../controllers/prompt_actions.dart';
part '../dialogs/add_text_dialog.dart';
part '../dialogs/add_url_dialog.dart';
part '../dialogs/prompt_form_dialog.dart';
part '../dialogs/skill_form_dialog.dart';

/// Categorías de skill — mismo set de 9 valores que frontend_react
/// (`resource-icons.tsx` / `SkillCategoryGlyph`).
const kSkillCategories = [
  'ai',
  'messaging',
  'notes',
  'productivity',
  'dev',
  'security',
  'media',
  'data',
  'company',
];

/// Icono simple (Material, sin emoji libre) según la categoría de la skill —
/// mismo criterio que `SkillCategoryGlyph` en frontend_react, pero con
/// iconos de Material en vez de SVG a medida.
IconData skillCategoryIcon(String category) {
  return switch (category) {
    'ai' => Icons.smart_toy_outlined,
    'messaging' => Icons.chat_bubble_outline,
    'notes' => Icons.description_outlined,
    'productivity' => Icons.check_circle_outline,
    'dev' => Icons.code,
    'security' => Icons.shield_outlined,
    'media' => Icons.play_circle_outline,
    'data' => Icons.storage_outlined,
    'company' => Icons.apartment_outlined,
    _ => Icons.circle_outlined,
  };
}

/// Etiqueta legible por categoría — mismos textos que
/// `skills.categories.*` en frontend_react (sin emoji).
String skillCategoryLabel(String category) {
  return switch (category) {
    'ai' => 'IA y Agentes',
    'messaging' => 'Mensajería',
    'notes' => 'Notas',
    'productivity' => 'Productividad',
    'dev' => 'Desarrollo',
    'security' => 'Seguridad',
    'media' => 'Media',
    'data' => 'Datos',
    'company' => 'Empresa',
    _ => 'Sin categoría',
  };
}

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage>
    with SingleTickerProviderStateMixin {
  late final KnowledgeRepository _repository;
  late final SkillsRepository _skillsRepository;
  late final PromptsRepository _promptsRepository;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  /// Cinco pestañas independientes para cada tipo de conocimiento.
  /// (no una sección "Conocimiento" genérica con filtro de tipo).
  static const _sectionIds = [
    'skills',
    'prompts',
    'urls',
    'documents',
    'memory',
  ];

  List<KnowledgeItem> _items = const [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  List<SkillItem> _skills = const [];
  bool _skillsLoading = true;
  String? _skillsError;

  List<PromptItem> _prompts = const [];
  bool _promptsLoading = true;
  String? _promptsError;
  String _promptScope = 'all';

  String? _activeGroupId;
  String _knowledgeOrigin = 'all';
  String _skillScope = 'all';
  String _skillCategory = 'all';

  List<KnowledgeItem> get _urlItems => _items
      .where((item) => item.type == 'url')
      .where(_matchesKnowledgeOrigin)
      .toList();
  List<KnowledgeItem> get _documentItems => _items
      .where((item) => item.type != 'url')
      .where(_matchesKnowledgeOrigin)
      .toList();

  bool _matchesKnowledgeOrigin(KnowledgeItem item) {
    if (_knowledgeOrigin == 'own') return !item.shared;
    if (_knowledgeOrigin == 'linked') return item.shared;
    return true;
  }

  int get _knowledgeFilterCount => _knowledgeOrigin != 'all' ? 1 : 0;

  List<String> get _skillCategoryOptions =>
      _skills.map((s) => s.category).where((c) => c.isNotEmpty).toSet().toList()
        ..sort();

  int get _skillFilterCount =>
      (_skillScope != 'all' ? 1 : 0) + (_skillCategory != 'all' ? 1 : 0);

  List<SkillItem> get _filteredSkills => _skills.where((item) {
    if (_skillScope != 'all' && item.scope != _skillScope) return false;
    if (_skillCategory != 'all' && item.category != _skillCategory) {
      return false;
    }
    return true;
  }).toList();

  int get _promptFilterCount => _promptScope != 'all' ? 1 : 0;

  List<PromptItem> get _filteredPrompts => _prompts.where((item) {
    if (_promptScope != 'all' && item.scope != _promptScope) return false;
    return true;
  }).toList();

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);
  void _refresh(VoidCallback update) => setState(update);

  void _openKnowledgeFiltersDialog() {
    final optionAll = _tx('explore.option_all', 'Todas');
    final originOptions = [
      ('all', optionAll),
      ('own', _tx('knowledge.origin_own', 'Propio')),
      ('linked', _tx('knowledge.origin_linked', 'Enlazado')),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => _refresh(() => _knowledgeOrigin = 'all'),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('knowledge.origin_label', 'Origen'),
          value: _knowledgeOrigin,
          options: originOptions,
          onChanged: (v) {
            _refresh(() => _knowledgeOrigin = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  void _openSkillFiltersDialog() {
    final optionAll = _tx('explore.option_all', 'Todas');
    final scopeOptions = [
      ('all', optionAll),
      ('private', _tx('agents.scope_private', 'Privado')),
      ('public', _tx('agents.scope_public', 'Público')),
    ];
    final categoryOptions = [
      ('all', optionAll),
      ..._skillCategoryOptions.map((c) => (c, skillCategoryLabel(c))),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => _refresh(() {
        _skillScope = 'all';
        _skillCategory = 'all';
      }),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label', 'Visibilidad'),
          value: _skillScope,
          options: scopeOptions,
          onChanged: (v) {
            _refresh(() => _skillScope = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('knowledge.category_label', 'Categoría'),
          value: _skillCategory,
          options: categoryOptions,
          onChanged: (v) {
            _refresh(() => _skillCategory = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  void _openPromptFiltersDialog() {
    final optionAll = _tx('explore.option_all', 'Todas');
    final scopeOptions = [
      ('all', optionAll),
      ('private', _tx('agents.scope_private', 'Privado')),
      ('public', _tx('agents.scope_public', 'Público')),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => _refresh(() => _promptScope = 'all'),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label', 'Visibilidad'),
          value: _promptScope,
          options: scopeOptions,
          onChanged: (v) {
            _refresh(() => _promptScope = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _repository = KnowledgeRepository(apiClient: widget.apiClient);
    _skillsRepository = SkillsRepository(apiClient: widget.apiClient);
    _promptsRepository = PromptsRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: _sectionIds.length, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
    _loadSkills();
    _loadPrompts();
  }

  void _onTextsChanged() {
    if (mounted) _refresh(() {});
  }

  void _onTabChanged() {
    if (mounted) _refresh(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final section = _sectionIds[_tabController.index];
    final tabLabels = [
      _tx('knowledge.tab_skills', 'Skills'),
      _tx('knowledge.tab_prompts', 'Prompts'),
      _tx('knowledge.tab_urls', 'URLs'),
      _tx('knowledge.tab_documents', 'Documentos'),
      _tx('knowledge.tab_memory', 'Memoria'),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: Colors.transparent,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ),
        ),
        Expanded(child: _buildSection(section)),
      ],
    );
  }

  /// Botón de grupos, junto al resto de acciones de cada sección — igual
  /// posición/orden que en Agents/Connections (Crear → Actualizar → Filtros
  /// → Grupos → chip de grupo activo).
  List<Widget> _groupsButtons() {
    return [
      AppIconButton.outlined(
        onPressed: () => showGroupFilterDialog(
          context,
          apiClient: widget.apiClient,
          token: _token ?? '',
          activeGroupId: _activeGroupId,
          onSelect: _onGroupSelect,
          localeController: widget.localeController,
        ),
        icon: const Icon(Icons.groups_outlined),
        tooltip: _tx('groups.toggle_tooltip', 'Grupos'),
        isSelected: _activeGroupId != null,
      ),
      if (_activeGroupId != null)
        ActionChip(
          label: Text(_tx('groups.active_clear', 'Grupo activo ✕')),
          onPressed: () => _onGroupSelect(null),
        ),
    ];
  }

  Widget _buildSection(String section) {
    return switch (section) {
      'prompts' => _buildPromptsSection(),
      'urls' => _buildUrlsSection(),
      'documents' => _buildDocumentsSection(),
      'memory' => MemoryPage(
        apiClient: widget.apiClient,
        sessionController: widget.sessionController,
        localeController: widget.localeController,
      ),
      _ => _buildSkillsSection(),
    };
  }
}
