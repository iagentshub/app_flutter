import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/explore/explore_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/tools/tool_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/state/watches_resource_changes.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/utils/memoized.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/resource_collection_view.dart';
import '../../../shared/widgets/resource_history_dialog.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../connections/repositories/connections_repository.dart';
import '../../explore/repositories/explore_repository.dart';
import '../../knowledge/repositories/knowledge_repository.dart';
import '../../knowledge/repositories/prompts_repository.dart';
import '../../knowledge/repositories/skills_repository.dart';
import '../../knowledge/repositories/tools_repository.dart';
import '../cards/agent_card.dart';
import '../repositories/agents_repository.dart';
import 'agent_builder_page.dart';
import 'agent_form_page.dart';
import 'chat_page.dart';
import 'public_agent_picker_page.dart';

part '../widgets/agents_page_actions.dart';
part '../widgets/agents_page_view.dart';

class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage>
    with StateMessaging, WatchesResourceChanges {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final AgentsRepository _repository;
  late final SkillsRepository _skillsRepository;
  late final KnowledgeRepository _knowledgeRepository;
  late final PromptsRepository _promptsRepository;
  late final ToolsRepository _toolsRepository;
  late final ConnectionsRepository _connectionsRepository;
  late final TranslatedTexts _t;
  final TextEditingController _queryController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();
  List<AgentItem> _agents = const [];

  /// id → nombre, para resolver las skills/knowledge/prompts de un agente en
  /// el grafo de contenido (AgentCard) — el agente solo guarda IDs.
  Map<String, String> _skillNames = const {};
  Map<String, String> _knowledgeNames = const {};
  Map<String, String> _knowledgePackNames = const {};
  Map<String, List<KnowledgeItem>> _knowledgePackItems = const {};
  Map<String, String> _promptNames = const {};
  Map<String, String> _toolNames = const {};

  /// id de conexión → nombre del modelo — la card muestra el modelo en vez
  /// del id crudo de la conexión.
  Map<String, String> _connectionNames = const {};
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _activeGroupId;
  String _scope = 'all';
  String _agentType = 'all';
  String _memory = 'all';

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  List<String> get _agentTypeOptions =>
      _agents.map((a) => a.agentType).toSet().toList()..sort();

  int get _activeFilterCount =>
      (_scope != 'all' ? 1 : 0) +
      (_agentType != 'all' ? 1 : 0) +
      (_memory != 'all' ? 1 : 0);

  final _filteredAgentsMemo = Memoized<List<AgentItem>>();

  List<AgentItem> get _filteredAgents => _filteredAgentsMemo.of(
    [_agents, _scope, _agentType, _memory, _query],
    () {
      final query = _query.trim().toLowerCase();
      return _agents.where((item) {
        if (_scope != 'all' && item.scope != _scope) return false;
        if (_agentType != 'all' && item.agentType != _agentType) return false;
        if (_memory == 'with' && !item.useMemory) return false;
        if (_memory == 'without' && item.useMemory) return false;
        if (query.isEmpty) return true;
        return item.name.toLowerCase().contains(query) ||
            item.agentType.toLowerCase().contains(query) ||
            item.model.toLowerCase().contains(query);
      }).toList();
    },
  );

  void _openFiltersDialog() {
    final optionAll = _tx('explore.option_all', 'Todas');
    final scopeOptions = [
      ('all', optionAll),
      ('private', _tx('agents.scope_private', 'Privado')),
      ('public', _tx('agents.scope_public', 'Público')),
    ];
    final typeOptions = [
      ('all', optionAll),
      ..._agentTypeOptions.map((t) => (t, t)),
    ];
    final memoryOptions = [
      ('all', optionAll),
      ('with', _tx('agents.memory_with', 'Con memoria')),
      ('without', _tx('agents.memory_without', 'Sin memoria')),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters', 'Filtros'),
      clearLabel: _tx('common.clear_filters', 'Limpiar filtros'),
      closeLabel: _tx('common.close', 'Cerrar'),
      onClear: () => setState(() {
        _scope = 'all';
        _agentType = 'all';
        _memory = 'all';
      }),
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
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('agents.type_label', 'Tipo de agente'),
          value: _agentType,
          options: typeOptions,
          onChanged: (v) {
            setState(() => _agentType = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('agents.memory_label', 'Memoria'),
          value: _memory,
          options: memoryOptions,
          onChanged: (v) {
            setState(() => _memory = v);
            setDialogState(() {});
          },
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _repository = AgentsRepository(apiClient: _services.apiClient);
    _skillsRepository = SkillsRepository(apiClient: _services.apiClient);
    _knowledgeRepository = KnowledgeRepository(apiClient: _services.apiClient);
    _promptsRepository = PromptsRepository(apiClient: _services.apiClient);
    _toolsRepository = ToolsRepository(apiClient: _services.apiClient);
    _connectionsRepository = ConnectionsRepository(
      apiClient: _services.apiClient,
    );
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  /// Compartir o dejar de compartir cambia lo que el listado marca como
  /// compartido, así que también cuenta como un cambio de agentes.
  @override
  Set<String> get watchedResources => const {'agents', 'sharing'};

  @override
  Future<void> onResourcesChanged(Set<String> changed) => _load();

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _queryController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => _services.sessionController.gaToken;

  Future<void> _load() async {
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
        _repository.listAgents(
          token,
          groupId: _activeGroupId,
          includeInactive: true,
        ),
        _skillsRepository.listSkills(token, includeInactive: true),
        _knowledgeRepository.listItems(token),
        _knowledgeRepository.listPacks(token),
        _promptsRepository.listPrompts(token, includeInactive: true),
        _toolsRepository.listTools(token, includeInactive: true),
        _connectionsRepository.listConnections(token, includeInactive: true),
      ]);
      if (!mounted) return;
      final skills = results[1] as List<SkillItem>;
      final knowledge = results[2] as List<KnowledgeItem>;
      final packs = results[3] as List<KnowledgePack>;
      final prompts = results[4] as List<PromptItem>;
      final tools = results[5] as List<ToolItem>;
      final connections = results[6] as List<ConnectionItem>;
      setState(() {
        _agents = results[0] as List<AgentItem>;
        _skillNames = {for (final s in skills) s.id: s.name};
        _knowledgeNames = {for (final k in knowledge) k.id: k.name};
        _knowledgePackNames = {for (final pack in packs) pack.id: pack.name};
        _knowledgePackItems = {
          for (final pack in packs)
            pack.id: knowledge.where((item) => item.packId == pack.id).toList(),
        };
        _promptNames = {for (final p in prompts) p.id: p.name};
        _toolNames = {for (final t in tools) t.id: t.name};
        _connectionNames = {
          for (final c in connections)
            c.id: c.model.isNotEmpty ? c.model : c.name,
        };
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
        _error = _tx(
          'agents.error_generic',
          'No se pudieron cargar los agentes',
        );
        _loading = false;
      });
    }
  }

  void _onGroupSelect(String? groupId) {
    setState(() => _activeGroupId = groupId);
    _load();
  }

  @override
  Widget build(BuildContext context) => _buildPage(context);
}
