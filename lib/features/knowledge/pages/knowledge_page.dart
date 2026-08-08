import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../features/memory/pages/memory_page.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/tools/tool_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/tools/tool_language.dart';
import '../../../shared/utils/memoized.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/grouped_label_picker.dart';
import '../../../shared/widgets/inactive_badge.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_history_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../repositories/knowledge_repository.dart';
import '../repositories/prompts_repository.dart';
import '../repositories/skills_repository.dart';
import '../repositories/tools_repository.dart';
import 'skill_builder_page.dart';

part '../cards/knowledge_sections.dart';
part '../cards/prompt_sections.dart';
part '../cards/tool_sections.dart';
part '../controllers/knowledge_actions.dart';
part '../controllers/prompt_actions.dart';
part '../controllers/tool_actions.dart';
part '../dialogs/add_text_dialog.dart';
part '../dialogs/add_url_dialog.dart';
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
String skillCategoryLabel(
  String Function(String path, String fallback) tx,
  String category,
) {
  return switch (category) {
    'ai' => tx('knowledge.category_ai', 'IA y Agentes'),
    'messaging' => tx('knowledge.category_messaging', 'Mensajería'),
    'notes' => tx('knowledge.category_notes', 'Notas'),
    'productivity' => tx('knowledge.category_productivity', 'Productividad'),
    'dev' => tx('knowledge.category_dev', 'Desarrollo'),
    'security' => tx('knowledge.category_security', 'Seguridad'),
    'media' => tx('knowledge.category_media', 'Media'),
    'data' => tx('knowledge.category_data', 'Datos'),
    'company' => tx('knowledge.category_company', 'Empresa'),
    _ => tx('knowledge.category_none', 'Sin categoría'),
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
    with SingleTickerProviderStateMixin, StateMessaging {
  late final KnowledgeRepository _repository;
  late final SkillsRepository _skillsRepository;
  late final PromptsRepository _promptsRepository;
  late final ToolsRepository _toolsRepository;
  late final TranslatedTexts _t;
  late final TabController _tabController;

  /// Seis pestañas independientes para cada tipo de conocimiento.
  /// (no una sección "Conocimiento" genérica con filtro de tipo).
  static const _sectionIds = [
    'skills',
    'prompts',
    'tools',
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

  List<ToolItem> _tools = const [];
  bool _toolsLoading = true;
  String? _toolsError;
  String _toolScope = 'all';
  String _toolLanguage = 'all';

  String? _activeGroupId;
  String _knowledgeOrigin = 'all';
  String _skillScope = 'all';
  String _skillCategory = 'all';

  final _urlItemsMemo = Memoized<List<KnowledgeItem>>();
  final _documentItemsMemo = Memoized<List<KnowledgeItem>>();

  List<KnowledgeItem> get _urlItems =>
      _urlItemsMemo.of([_items, _knowledgeOrigin], () {
        return _items
            .where((item) => item.type == 'url')
            .where(_matchesKnowledgeOrigin)
            .toList();
      });

  List<KnowledgeItem> get _documentItems =>
      _documentItemsMemo.of([_items, _knowledgeOrigin], () {
        return _items
            .where((item) => item.type != 'url')
            .where(_matchesKnowledgeOrigin)
            .toList();
      });

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

  final _filteredSkillsMemo = Memoized<List<SkillItem>>();

  List<SkillItem> get _filteredSkills =>
      _filteredSkillsMemo.of([_skills, _skillScope, _skillCategory], () {
        return _skills.where((item) {
          if (_skillScope != 'all' && item.scope != _skillScope) return false;
          if (_skillCategory != 'all' && item.category != _skillCategory) {
            return false;
          }
          return true;
        }).toList();
      });

  int get _promptFilterCount => _promptScope != 'all' ? 1 : 0;

  final _filteredPromptsMemo = Memoized<List<PromptItem>>();

  List<PromptItem> get _filteredPrompts => _filteredPromptsMemo.of(
    [_prompts, _promptScope],
    () {
      return _prompts
          .where((item) => _promptScope == 'all' || item.scope == _promptScope)
          .toList();
    },
  );

  List<String> get _toolLanguageOptions =>
      _tools.map((t) => t.language).where((l) => l.isNotEmpty).toSet().toList()
        ..sort();

  int get _toolFilterCount =>
      (_toolScope != 'all' ? 1 : 0) + (_toolLanguage != 'all' ? 1 : 0);

  final _filteredToolsMemo = Memoized<List<ToolItem>>();

  List<ToolItem> get _filteredTools =>
      _filteredToolsMemo.of([_tools, _toolScope, _toolLanguage], () {
        return _tools.where((item) {
          if (_toolScope != 'all' && item.scope != _toolScope) return false;
          if (_toolLanguage != 'all' && item.language != _toolLanguage) {
            return false;
          }
          return true;
        }).toList();
      });

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

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
      onClear: () => refresh(() => _knowledgeOrigin = 'all'),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('knowledge.origin_label', 'Origen'),
          value: _knowledgeOrigin,
          options: originOptions,
          onChanged: (v) {
            refresh(() => _knowledgeOrigin = v);
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
      ..._skillCategoryOptions.map((c) => (c, skillCategoryLabel(_tx, c))),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => refresh(() {
        _skillScope = 'all';
        _skillCategory = 'all';
      }),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label', 'Visibilidad'),
          value: _skillScope,
          options: scopeOptions,
          onChanged: (v) {
            refresh(() => _skillScope = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('knowledge.category_label', 'Categoría'),
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
      onClear: () => refresh(() => _promptScope = 'all'),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label', 'Visibilidad'),
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
    final optionAll = _tx('explore.option_all', 'Todas');
    final scopeOptions = [
      ('all', optionAll),
      ('private', _tx('agents.scope_private', 'Privado')),
      ('public', _tx('agents.scope_public', 'Público')),
    ];
    final languageOptions = [
      ('all', optionAll),
      ..._toolLanguageOptions.map((l) => (l, toolLanguageLabel(_tx, l))),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => refresh(() {
        _toolScope = 'all';
        _toolLanguage = 'all';
      }),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label', 'Visibilidad'),
          value: _toolScope,
          options: scopeOptions,
          onChanged: (v) {
            refresh(() => _toolScope = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('knowledge.field_language', 'Lenguaje'),
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
    _repository = KnowledgeRepository(apiClient: widget.apiClient);
    _skillsRepository = SkillsRepository(apiClient: widget.apiClient);
    _promptsRepository = PromptsRepository(apiClient: widget.apiClient);
    _toolsRepository = ToolsRepository(apiClient: widget.apiClient);
    _tabController = TabController(length: _sectionIds.length, vsync: this)
      ..addListener(_onTabChanged);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _ensureSectionLoaded(_sectionIds.first);
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
    // `urls` y `documents` salen del mismo listado de Knowledge.
    final clave = section == 'documents' ? 'urls' : section;
    if (!_loadedSections.add(clave)) return;
    switch (clave) {
      case 'skills':
        _loadSkills();
      case 'prompts':
        _loadPrompts();
      case 'tools':
        _loadTools();
      case 'urls':
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
      _tx('knowledge.tab_skills', 'Skills'),
      _tx('knowledge.tab_prompts', 'Prompts'),
      _tx('knowledge.tab_tools', 'Herramientas'),
      _tx('knowledge.tab_urls', 'URLs'),
      _tx('knowledge.tab_documents', 'Documentos'),
      _tx('knowledge.tab_memory', 'Memoria'),
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
      'tools' => _buildToolsSection(),
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
