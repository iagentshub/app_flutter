import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/page_result.dart';
import '../../../features/memory/pages/memory_page.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/tools/tool_models.dart';
import '../../../shared/graph/resource_graph_builder.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/state/upload_limits.dart';
import '../../../shared/state/watches_resource_changes.dart';
import '../../../shared/tools/tool_language.dart';
import '../../../shared/utils/memoized.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/buttons/overflow_menu_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/grouped_label_picker.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_collection_view.dart';
import '../../../shared/widgets/resource_graph_button.dart';
import '../../../shared/widgets/resource_history_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../../utils/i18n.dart';
import '../../agents/repositories/agents_repository.dart';
import '../dialogs/knowledge_pack_dialog.dart';
import '../dialogs/knowledge_pack_upload_progress_dialog.dart';
import '../models/local_knowledge_file.dart';
import '../repositories/knowledge_repository.dart';
import '../repositories/prompts_repository.dart';
import '../repositories/skills_repository.dart';
import '../repositories/tools_repository.dart';
import '../services/directory_picker.dart';
import 'skill_builder_page.dart';

part '../cards/knowledge_image_card.dart';
part '../cards/knowledge_pack_card.dart';
part '../cards/knowledge_resource_graph.dart';
part '../cards/knowledge_sections.dart';
part '../cards/prompt_sections.dart';
part '../cards/tool_sections.dart';
part '../controllers/document_actions.dart';
part '../controllers/knowledge_actions.dart';
part '../controllers/knowledge_filters.dart';
part '../controllers/knowledge_pack_actions.dart';
part '../controllers/prompt_actions.dart';
part '../controllers/tool_actions.dart';
part '../dialogs/add_text_dialog.dart';
part '../dialogs/add_url_dialog.dart';
part '../dialogs/content_language_dialog.dart';
part '../dialogs/knowledge_labels_dialog.dart';
part '../dialogs/prompt_form_dialog.dart';
part '../dialogs/skill_form_dialog.dart';
part '../dialogs/tool_form_dialog.dart';

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

/// Etiqueta legible por categoría, siempre vía `tx` — mismo patrón que
/// [toolLanguageLabel], que está justo al lado y ya lo hacía bien.
///
/// Estaba fija en español para todos los idiomas: es la etiqueta que se ve en
/// el filtro de categorías y en cada tarjeta de skill, así que un usuario con
/// la app en inglés leía «IA y Agentes» y «Mensajería».
String skillCategoryLabel(String Function(String path) tx, String category) {
  return switch (category) {
    'ai' => tx('knowledge.category_ai'),
    'messaging' => tx('knowledge.category_messaging'),
    'notes' => tx('knowledge.category_notes'),
    'productivity' => tx('knowledge.category_productivity'),
    'dev' => tx('knowledge.category_dev'),
    'security' => tx('knowledge.category_security'),
    'media' => tx('knowledge.category_media'),
    'data' => tx('knowledge.category_data'),
    'company' => tx('knowledge.category_company'),
    _ => tx('knowledge.category_none'),
  };
}

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({super.key});

  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage>
    with
        SingleTickerProviderStateMixin,
        StateMessaging,
        WatchesResourceChanges {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final KnowledgeRepository _repository;
  late final AgentsRepository _agentsRepository;
  late final SkillsRepository _skillsRepository;
  late final PromptsRepository _promptsRepository;
  late final ToolsRepository _toolsRepository;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  /// Cinco pestañas; URLs y ficheros conviven en Documentos.
  /// (no una sección "Conocimiento" genérica con filtro de tipo).
  static const _sectionIds = [
    'skills',
    'prompts',
    'tools',
    'documents',
    'memory',
  ];

  List<KnowledgeItem> _items = const [];
  bool _hasMoreKnowledge = false;
  bool _loadingMoreKnowledge = false;
  List<KnowledgePack> _packs = const [];
  Future<List<AgentItem>>? _graphRelations;
  bool _loading = true;
  bool _uploading = false;
  String? _packOperationMessage;
  bool _draggingDirectory = false;
  String? _error;

  List<SkillItem> _skills = const [];
  bool _skillsLoading = true;
  String? _skillsError;

  List<PromptItem> _prompts = const [];
  bool _promptsLoading = true;
  String? _promptsError;
  String _promptScope = 'all';

  List<ToolItem> _tools = const [];
  bool _toolsLoading = true;
  String? _toolsError;
  String _toolScope = 'all';
  String _toolLanguage = 'all';

  String? _activeGroupId;
  String _knowledgeOrigin = 'all';
  bool _knowledgePacksMode = true;
  String _skillScope = 'all';
  String _skillCategory = 'all';

  final _urlItemsMemo = Memoized<List<KnowledgeItem>>();
  final _documentItemsMemo = Memoized<List<KnowledgeItem>>();

  final _filteredSkillsMemo = Memoized<List<SkillItem>>();
  final _filteredPromptsMemo = Memoized<List<PromptItem>>();
  final _filteredToolsMemo = Memoized<List<ToolItem>>();

  String _tx(String path) => _t.text(path);

  void _openKnowledgeFiltersDialog() {
    final optionAll = _tx('explore.option_all');
    final originOptions = [
      ('all', optionAll),
      ('owner', _tx('knowledge.origin_owner')),
      ('linked', _tx('knowledge.origin_linked')),
      ('fork', _tx('knowledge.origin_fork')),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () {
        refresh(() {
          _knowledgeOrigin = 'all';
          _knowledgePacksMode = true;
        });
        _ensureKnowledgeCollectionFilled();
      },
      buildFields: (setDialogState) => [
        Text(
          _tx('knowledge.pack_display_label'),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<bool>(
            key: const ValueKey('knowledge-pack-mode-selector'),
            segments: [
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: Text(_tx('knowledge.pack_mode')),
              ),
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.view_module_outlined, size: 16),
                label: Text(_tx('knowledge.individual_mode')),
              ),
            ],
            selected: {_knowledgePacksMode},
            showSelectedIcon: false,
            expandedInsets: EdgeInsets.zero,
            onSelectionChanged: (values) {
              refresh(() => _knowledgePacksMode = values.first);
              setDialogState(() {});
              _ensureKnowledgeCollectionFilled();
            },
          ),
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('knowledge.origin_label'),
          value: _knowledgeOrigin,
          options: originOptions,
          onChanged: (v) {
            refresh(() => _knowledgeOrigin = v);
            setDialogState(() {});
            _ensureKnowledgeCollectionFilled();
          },
        ),
      ],
    );
  }

  void _openSkillFiltersDialog() {
    final optionAll = _tx('explore.option_all');
    final scopeOptions = [
      ('all', optionAll),
      ('private', _tx('agents.scope_private')),
      ('public', _tx('agents.scope_public')),
    ];
    final categoryOptions = [
      ('all', optionAll),
      ..._skillCategoryOptions.map((c) => (c, skillCategoryLabel(_tx, c))),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () => refresh(() {
        _skillScope = 'all';
        _skillCategory = 'all';
      }),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label'),
          value: _skillScope,
          options: scopeOptions,
          onChanged: (v) {
            refresh(() => _skillScope = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('knowledge.category_label'),
          value: _skillCategory,
          options: categoryOptions,
          onChanged: (v) {
            refresh(() => _skillCategory = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  void _openPromptFiltersDialog() {
    final optionAll = _tx('explore.option_all');
    final scopeOptions = [
      ('all', optionAll),
      ('private', _tx('agents.scope_private')),
      ('public', _tx('agents.scope_public')),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () => refresh(() => _promptScope = 'all'),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label'),
          value: _promptScope,
          options: scopeOptions,
          onChanged: (v) {
            refresh(() => _promptScope = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  void _openToolFiltersDialog() {
    final optionAll = _tx('explore.option_all');
    final scopeOptions = [
      ('all', optionAll),
      ('private', _tx('agents.scope_private')),
      ('public', _tx('agents.scope_public')),
    ];
    final languageOptions = [
      ('all', optionAll),
      ..._toolLanguageOptions.map((l) => (l, toolLanguageLabel(_tx, l))),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () => refresh(() {
        _toolScope = 'all';
        _toolLanguage = 'all';
      }),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label'),
          value: _toolScope,
          options: scopeOptions,
          onChanged: (v) {
            refresh(() => _toolScope = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('knowledge.field_language'),
          value: _toolLanguage,
          options: languageOptions,
          onChanged: (v) {
            refresh(() => _toolLanguage = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _repository = KnowledgeRepository(apiClient: _services.apiClient);
    _agentsRepository = AgentsRepository(apiClient: _services.apiClient);
    _skillsRepository = SkillsRepository(apiClient: _services.apiClient);
    _promptsRepository = PromptsRepository(apiClient: _services.apiClient);
    _toolsRepository = ToolsRepository(apiClient: _services.apiClient);
    _tabController = TabController(length: _sectionIds.length, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _ensureSectionLoaded(_sectionIds.first);
  }

  /// Compartir arrastra skills, prompts y knowledge de un agente, así que un
  /// cambio en «sharing» puede alterar cualquiera de las cuatro pestañas.
  @override
  Set<String> get watchedResources => const {
    'knowledge',
    'skills',
    'prompts',
    'tools',
    'sharing',
  };

  @override
  Future<void> onResourcesChanged(Set<String> changed) async {
    // Solo se refresca lo que el usuario ha llegado a abrir: recargar una
    // pestaña que nunca ha visto desharía la carga perezosa por sección.
    final todas = changed.contains('sharing');
    if (todas || changed.contains('skills')) _recargarSeccion('skills');
    if (todas || changed.contains('prompts')) _recargarSeccion('prompts');
    if (todas || changed.contains('tools')) _recargarSeccion('tools');
    if (todas || changed.contains('knowledge')) _recargarSeccion('documents');
  }

  void _recargarSeccion(String seccion) {
    if (!_loadedSections.contains(seccion)) return;
    switch (seccion) {
      case 'skills':
        _loadSkills();
      case 'prompts':
        _loadPrompts();
      case 'tools':
        _loadTools();
      case 'documents':
        _load();
    }
  }

  void _onTextsChanged() {
    if (mounted) refresh(() {});
  }

  void _onTabChanged() {
    if (!mounted) return;
    _ensureSectionLoaded(_sectionIds[_tabController.index]);
    refresh(() {});
  }

  /// Secciones cuyo listado ya se ha pedido alguna vez.
  final Set<String> _loadedSections = {};

  /// La página arrancaba disparando las cuatro cargas a la vez, con seis
  /// pestañas y solo la primera a la vista: tres de esas peticiones eran para
  /// contenido que el usuario todavía no miraba —y puede que no mirara nunca—
  /// y en una conexión lenta competían con la pestaña visible. Cada sección se
  /// carga la primera vez que se abre; volver a ella no repite la petición, y
  /// la caché de 60 s de ApiClient mantiene la sensación de instantaneidad.
  void _ensureSectionLoaded(String section) {
    final clave = section;
    if (!_loadedSections.add(clave)) return;
    switch (clave) {
      case 'skills':
        _loadSkills();
      case 'prompts':
        _loadPrompts();
      case 'tools':
        _loadTools();
      case 'documents':
        _load();
      // `memory` monta MemoryPage, que carga lo suyo por su cuenta.
    }
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
      _tx('knowledge.tab_skills'),
      _tx('knowledge.tab_prompts'),
      _tx('knowledge.tab_tools'),
      _tx('knowledge.tab_documents'),
      _tx('knowledge.tab_memory'),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Material(
            color: FncColors.transparent,
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
          apiClient: _services.apiClient,
          token: _token ?? '',
          activeGroupId: _activeGroupId,
          onSelect: _onGroupSelect,
          localeController: _services.localeController,
        ),
        icon: const Icon(Icons.groups_outlined),
        tooltip: _tx('groups.toggle_tooltip'),
        isSelected: _activeGroupId != null,
      ),
      if (_activeGroupId != null)
        ActionChip(
          label: Text(_tx('groups.active_clear')),
          onPressed: () => _onGroupSelect(null),
        ),
    ];
  }

  Widget _buildSection(String section) {
    return switch (section) {
      'prompts' => _buildPromptsSection(),
      'tools' => _buildToolsSection(),
      'documents' => _buildDocumentsSection(),
      'memory' => const MemoryPage(),
      _ => _buildSkillsSection(),
    };
  }
}
