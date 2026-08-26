import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/config/directory_import_policy.dart';
import '../../../core/network/api_error.dart';
import '../../../models/agents/agent_import_models.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/agents/agent_resource_catalog.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/explore/explore_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/prompts/prompt_models.dart';
import '../../../models/skills/skill_models.dart';
import '../../../models/tools/tool_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/state/upload_limits.dart';
import '../../../shared/state/watches_resource_changes.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/utils/memoized.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/iagents_async_view.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/resource_collection_view.dart';
import '../../../shared/widgets/resource_history_dialog.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../connections/repositories/connections_repository.dart';
import '../../executions/controllers/resource_executions_controller.dart';
import '../../explore/repositories/explore_repository.dart';
import '../../knowledge/models/local_knowledge_file.dart';
import '../../knowledge/services/directory_picker.dart';
import '../cards/agent_card.dart';
import '../dialogs/agent_directory_import_dialog.dart';
import '../dialogs/agent_import_preview_dialog.dart';
import '../repositories/agent_import_repository.dart';
import '../repositories/agents_repository.dart';
import 'agent_builder_page.dart';
import 'agent_form_page.dart';
import 'chat_page.dart';
import 'public_agent_picker_page.dart';

part '../widgets/agents_page_actions.dart';
part '../widgets/agents_page_import_actions.dart';
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
  late final AgentImportRepository _agentImportRepository;
  late final ConnectionsRepository _connectionsRepository;
  late final TranslatedTexts _t;
  late final ResourceExecutionsController? _executionState;
  final TextEditingController _queryController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();
  List<AgentItem> _agents = const [];
  List<ConnectionItem> _connections = const [];
  AgentResourceCatalog _agentResourceCatalog = const AgentResourceCatalog();

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
  bool _importingAgentFile = false;
  bool _draggingAgentFile = false;
  String? _error;
  String _query = '';
  String? _activeGroupId;
  String _scope = 'all';
  String _agentType = 'all';
  String _memory = 'all';

  String _tx(String path) => _t.text(path);

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
    final optionAll = _tx('explore.option_all');
    final scopeOptions = [
      ('all', optionAll),
      ('private', _tx('agents.scope_private')),
      ('public', _tx('agents.scope_public')),
    ];
    final typeOptions = [
      ('all', optionAll),
      ..._agentTypeOptions.map((t) => (t, t)),
    ];
    final memoryOptions = [
      ('all', optionAll),
      ('with', _tx('agents.memory_with')),
      ('without', _tx('agents.memory_without')),
    ];

    showFilterDialog(
      context,
      title: _tx('common.filters'),
      clearLabel: _tx('common.clear_filters'),
      closeLabel: _tx('common.close'),
      onClear: () => setState(() {
        _scope = 'all';
        _agentType = 'all';
        _memory = 'all';
      }),
      buildFields: (setDialogState) => [
        FilterDropdown(
          label: _tx('agents.scope_label'),
          value: _scope,
          options: scopeOptions,
          onChanged: (v) {
            setState(() => _scope = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('agents.type_label'),
          value: _agentType,
          options: typeOptions,
          onChanged: (v) {
            setState(() => _agentType = v);
            setDialogState(() {});
          },
        ),
        const SizedBox(height: 12),
        FilterDropdown(
          label: _tx('agents.memory_label'),
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
    _agentImportRepository = AgentImportRepository(
      apiClient: _services.apiClient,
    );
    _connectionsRepository = ConnectionsRepository(
      apiClient: _services.apiClient,
    );
    _executionState = _services.resourceExecutionsController;
    _executionState?.addListener(_onExecutionStateChanged);
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

  void _onExecutionStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _queryController.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    _executionState?.removeListener(_onExecutionStateChanged);
    super.dispose();
  }

  String? get _token => _services.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final coreResults = await Future.wait([
        _repository.listAgents(
          token,
          groupId: _activeGroupId,
          includeInactive: true,
        ),
        _connectionsRepository.listConnections(token, includeInactive: true),
      ]);
      final agents = coreResults[0] as List<AgentItem>;
      final catalog = await _resolveCatalogForAgents(token, agents);
      if (!mounted) return;
      final connections = coreResults[1] as List<ConnectionItem>;
      setState(() {
        _installLoadedData(
          agents: agents,
          connections: connections,
          skills: catalog.skills,
          knowledge: catalog.knowledge,
          packs: catalog.packs,
          prompts: catalog.prompts,
          tools: catalog.tools,
        );
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
        _error = _tx('agents.error_generic');
        _loading = false;
      });
    }
  }

  Future<AgentResourceCatalog> _resolveCatalogForAgents(
    String token,
    List<AgentItem> agents,
  ) => _agentImportRepository.resolveCatalog(token, {
    AgentResourceType.skill: agents.expand((item) => item.skills),
    AgentResourceType.knowledge: agents.expand((item) => item.knowledge),
    AgentResourceType.knowledgePack: agents.expand(
      (item) => item.knowledgePacks,
    ),
    AgentResourceType.prompt: agents.expand((item) => item.prompts),
    AgentResourceType.tool: agents.expand((item) => item.tools),
  });

  void _installLoadedData({
    required List<AgentItem> agents,
    required List<ConnectionItem> connections,
    required List<SkillItem> skills,
    required List<KnowledgeItem> knowledge,
    required List<KnowledgePack> packs,
    required List<PromptItem> prompts,
    required List<ToolItem> tools,
  }) {
    _agents = agents;
    _connections = connections;
    _skillNames = {for (final item in skills) item.id: item.name};
    _knowledgeNames = {for (final item in knowledge) item.id: item.name};
    _knowledgePackNames = {for (final item in packs) item.id: item.name};
    _knowledgePackItems = {
      for (final pack in packs)
        pack.id: knowledge.where((item) => item.packId == pack.id).toList(),
    };
    _promptNames = {for (final item in prompts) item.id: item.name};
    _toolNames = {for (final item in tools) item.id: item.name};
    _connectionNames = {
      for (final item in connections)
        item.id: item.model.isNotEmpty ? item.model : item.name,
    };
    _agentResourceCatalog = AgentResourceCatalog(
      connections: connections.where((item) => item.isActive).toList(),
      skills: skills,
      knowledge: knowledge,
      packs: packs,
      prompts: prompts,
      tools: tools,
    );
  }

  Future<void> _reloadAfterDirectoryImport() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final agents = await _repository.listAgents(
      token,
      groupId: _activeGroupId,
      includeInactive: true,
    );
    final catalog = await _resolveCatalogForAgents(token, agents);
    if (!mounted) return;
    setState(() {
      _installLoadedData(
        agents: agents,
        skills: catalog.skills,
        knowledge: catalog.knowledge,
        packs: catalog.packs,
        prompts: catalog.prompts,
        tools: catalog.tools,
        connections: _connections,
      );
    });
  }

  void _onGroupSelect(String? groupId) {
    setState(() => _activeGroupId = groupId);
    _load();
  }

  @override
  Widget build(BuildContext context) => _buildPage(context);
}
