import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../features/connections/repositories/connections_repository.dart';
import '../../../features/knowledge/repositories/knowledge_repository.dart';
import '../../../features/knowledge/repositories/skills_repository.dart';
import '../../../features/memory/repositories/memory_repository.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/connections/connection_models.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../models/memory/memory_models.dart';
import '../../../models/skills/skill_models.dart';
import '../repositories/agents_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/filter_button.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/grouped_label_picker.dart';
import '../../../shared/widgets/label_chips_row.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import 'chat_page.dart';

class AgentsPage extends StatefulWidget {
  const AgentsPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  late final AgentsRepository _repository;
  late final TranslatedTexts _t;
  final TextEditingController _queryController = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer();
  List<AgentItem> _agents = const [];
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

  List<AgentItem> get _filteredAgents {
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
  }

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
    _repository = AgentsRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

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

  String? get _token => widget.sessionController.gaToken;

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
      final agents = await _repository.listAgents(
        token,
        groupId: _activeGroupId,
      );
      if (!mounted) return;
      setState(() {
        _agents = agents;
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

  Future<void> _shareAgent(AgentItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'agent',
      resourceId: item.id,
      localeController: widget.localeController,
      onShared: _load,
    );
  }

  Future<void> _openCreateDialog() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _AgentFormDialog(apiClient: widget.apiClient, token: token, tx: _tx),
    );
    if (payload == null) return;
    await _saveAgent(payload);
  }

  Future<void> _openEditDialog(AgentItem item) async {
    if (item.readOnly) {
      _showMessage('Este agente no es editable (público o compartido)');
      return;
    }

    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _repository.getAgent(token, item.id);
    } catch (_) {}

    if (!mounted) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AgentFormDialog(
        apiClient: widget.apiClient,
        token: token,
        initial: initial,
        tx: _tx,
      ),
    );
    if (payload == null) return;
    payload['id'] = item.id;
    await _saveAgent(payload);
  }

  Future<void> _saveAgent(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.saveAgent(token, payload);
      _showMessage('Agente guardado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo guardar el agente', isError: true);
    }
  }

  Future<void> _deleteAgent(AgentItem item) async {
    if (item.readOnly) {
      _showMessage('Este agente no se puede eliminar (público o compartido)');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar agente'),
        content: Text('¿Seguro que quieres eliminar "${item.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.deleteAgent(token, item.id);
      _showMessage('Agente eliminado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar el agente', isError: true);
    }
  }

  void _openChat(AgentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          agent: item,
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
        ),
      ),
    );
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
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
                    _tx('agents.error_title', 'Error cargando agentes'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
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

    final filteredAgents = _filteredAgents;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      labelText: _tx('agents.search_hint', 'Buscar agente'),
                      prefixIcon: const Icon(Icons.search, size: 20),
                    ),
                    onChanged: (value) {
                      _query = value;
                      _searchDebouncer.run(() {
                        if (mounted) setState(() {});
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton.filled(
                        onPressed: _openCreateDialog,
                        icon: const Icon(Icons.add),
                        tooltip: _tx('agents.new', 'Nuevo agente'),
                      ),
                      IconButton.outlined(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh),
                        tooltip: _tx('common.update', 'Actualizar'),
                      ),
                      FilterButton(
                        activeCount: _activeFilterCount,
                        tooltip: _tx('common.filters', 'Filtros'),
                        onPressed: _openFiltersDialog,
                      ),
                      IconButton.outlined(
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
                          label: Text(
                            _tx('groups.active_clear', 'Grupo activo ✕'),
                          ),
                          onPressed: () => _onGroupSelect(null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${_tx('agents.count_label', 'Agentes')}: ${filteredAgents.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          if (filteredAgents.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _agents.isEmpty
                          ? _tx('agents.empty', 'No hay agentes disponibles.')
                          : _tx(
                              'agents.empty_search',
                              'Sin resultados para esa búsqueda.',
                            ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildAgentCard(filteredAgents[index]),
                  childCount: filteredAgents.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentCard(AgentItem item) {
    final subtitleParts = <String>[item.agentType];
    if (item.model.isNotEmpty) subtitleParts.add(item.model);
    if (item.connectionId.isNotEmpty)
      subtitleParts.add('conn: ${item.connectionId}');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitleParts.join(' · ')),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: item.labels,
              leading: [
                OriginBadge(
                  shared: item.shared,
                  ownerLabel: _tx('common.owner', 'Propietario'),
                  linkedLabel: _tx('common.linked', 'Enlazado'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Tooltip(
                  message: item.connectionId.isEmpty
                      ? _tx(
                          'agents.chat_no_connection',
                          'Configura una conexión para este agente',
                        )
                      : '',
                  child: FilledButton.icon(
                    onPressed: item.connectionId.isEmpty
                        ? null
                        : () => _openChat(item),
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: const Text('Chat'),
                  ),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: _tx('common.share_group', 'Compartir con grupo'),
                  onPressed: () => _shareAgent(item),
                ),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditDialog(item),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteAgent(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentFormDialog extends StatefulWidget {
  const _AgentFormDialog({
    required this.apiClient,
    required this.token,
    required this.tx,
    this.initial,
  });

  final ApiClient apiClient;
  final String token;
  final String Function(String path, String fallback) tx;
  final Map<String, dynamic>? initial;

  @override
  State<_AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<_AgentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _modelController;
  late final TextEditingController _promptController;
  late final TextEditingController _memoryFileController;
  late final ConnectionsRepository _connectionsRepository;
  late final MemoryRepository _memoryRepository;
  late final SkillsRepository _skillsRepository;
  late final KnowledgeRepository _knowledgeRepository;

  List<ConnectionItem> _connections = const [];
  bool _loadingConnections = true;
  String? _connectionId;
  double _temperature = 0.7;
  Set<String> _selectedLabels = {};
  String _agentType = 'generic';

  bool _useMemory = false;
  List<MemoryFileItem> _memoryFiles = const [];
  bool _loadingMemory = true;

  Set<String> _selectedSkillIds = {};
  List<SkillItem> _skills = const [];
  bool _loadingSkills = true;

  Set<String> _selectedKnowledgeIds = {};
  List<KnowledgeItem> _knowledgeItems = const [];
  bool _loadingKnowledge = true;

  /// La visibilidad ya no es un campo aparte: es la label "private"/"public"
  /// del grupo excluyente de Visibilidad (una sola fuente de verdad).
  String get _scope =>
      _selectedLabels.contains('public') ? 'public' : 'private';

  String get _title => widget.initial == null
      ? widget.tx('agents.new_title', 'Nuevo agente')
      : widget.tx('agents.edit_title', 'Editar agente');

  @override
  void initState() {
    super.initState();
    _connectionsRepository = ConnectionsRepository(apiClient: widget.apiClient);
    _memoryRepository = MemoryRepository(apiClient: widget.apiClient);
    _skillsRepository = SkillsRepository(apiClient: widget.apiClient);
    _knowledgeRepository = KnowledgeRepository(apiClient: widget.apiClient);
    final initial = widget.initial;
    _nameController = TextEditingController(
      text: initial?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: initial?['description']?.toString() ?? '',
    );
    _modelController = TextEditingController(
      text: initial?['model']?.toString() ?? '',
    );
    _promptController = TextEditingController(
      text: initial?['system_prompt']?.toString() ?? '',
    );

    final connId = initial?['connection_id']?.toString() ?? '';
    _connectionId = connId.isEmpty ? null : connId;
    _temperature =
        (num.tryParse(initial?['temperature']?.toString() ?? '0.7') ?? 0.7)
            .toDouble()
            .clamp(0.0, 1.0);

    final labelsRaw = initial?['labels'];
    _selectedLabels = labelsRaw is List
        ? labelsRaw.map((e) => e.toString()).toSet()
        : {'private'};
    if (!_selectedLabels.contains('private') &&
        !_selectedLabels.contains('public')) {
      _selectedLabels = {..._selectedLabels, 'private'};
    }

    _agentType = (initial?['agent_type'] as String?) ?? 'generic';

    final memoryFile = initial?['memory_file']?.toString() ?? '';
    _useMemory = memoryFile.isNotEmpty;
    _memoryFileController = TextEditingController(text: memoryFile);

    final skillsRaw = initial?['skills'];
    _selectedSkillIds = skillsRaw is List
        ? skillsRaw.map((e) => e.toString()).toSet()
        : {};
    final knowledgeRaw = initial?['knowledge'];
    _selectedKnowledgeIds = knowledgeRaw is List
        ? knowledgeRaw.map((e) => e.toString()).toSet()
        : {};

    _loadConnections();
    _loadMemory();
    _loadSkills();
    _loadKnowledge();
  }

  Future<void> _loadConnections() async {
    try {
      final list = await _connectionsRepository.listConnections(widget.token);
      if (!mounted) return;
      setState(() {
        _connections = list;
        _loadingConnections = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingConnections = false);
    }
  }

  Future<void> _loadMemory() async {
    try {
      final list = await _memoryRepository.listFiles(widget.token);
      if (!mounted) return;
      setState(() {
        _memoryFiles = list;
        _loadingMemory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMemory = false);
    }
  }

  Future<void> _loadSkills() async {
    try {
      final list = await _skillsRepository.listSkills(
        widget.token,
        scope: 'all',
      );
      if (!mounted) return;
      setState(() {
        _skills = list;
        _loadingSkills = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingSkills = false);
    }
  }

  Future<void> _loadKnowledge() async {
    try {
      final list = await _knowledgeRepository.listItems(widget.token);
      if (!mounted) return;
      setState(() {
        _knowledgeItems = list;
        _loadingKnowledge = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingKnowledge = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    _memoryFileController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'scope': _scope,
      'agent_type': _agentType,
      'model': _modelController.text.trim(),
      'connection_id': _connectionId ?? '',
      'system_prompt': _promptController.text.trim(),
      'temperature': _temperature,
      'labels': _selectedLabels.toList(),
      'memory_file': _useMemory && _memoryFileController.text.trim().isNotEmpty
          ? _memoryFileController.text.trim()
          : null,
      'skills': _selectedSkillIds.toList(),
      'knowledge': _selectedKnowledgeIds.toList(),
    };

    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: AlertDialog(
        title: Text(_title),
        contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
        content: SizedBox(
          width: 580,
          height: 480,
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: widget.tx('agents.tab_basic', 'Básico')),
                    Tab(text: widget.tx('agents.tab_connection', 'Conexión')),
                    Tab(
                      text: widget.tx('agents.tab_knowledge', 'Conocimiento'),
                    ),
                    Tab(text: widget.tx('agents.tab_advanced', 'Avanzado')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildBasicTab(),
                      _buildConnectionTab(),
                      _buildKnowledgeTab(),
                      _buildAdvancedTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(widget.tx('common.cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.tx('common.save', 'Guardar')),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_name', 'Nombre'),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty)
                return widget.tx(
                  'agents.name_required',
                  'El nombre es obligatorio',
                );
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_description', 'Descripción'),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.tx('agents.field_labels', 'Etiquetas'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          GroupedLabelPicker(
            selected: _selectedLabels,
            onChanged: (next) => setState(() => _selectedLabels = next),
            tx: widget.tx,
          ),
          TextFormField(
            controller: _promptController,
            minLines: 5,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_prompt', 'System prompt'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _loadingConnections
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : DropdownButtonFormField<String>(
                  initialValue: _connectionId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: widget.tx(
                      'agents.field_connection',
                      'Conexión LLM',
                    ),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        widget.tx('agents.no_connection', '-- Sin conexión --'),
                      ),
                    ),
                    ..._connections.map(
                      (conn) => DropdownMenuItem<String>(
                        value: conn.id,
                        child: Text(
                          '${conn.name} (${conn.type})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _connectionId = value),
                ),
          const SizedBox(height: 20),
          Text(
            '${widget.tx('agents.field_temperature', 'Temperatura')}: ${_temperature.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Slider(
            value: _temperature,
            min: 0,
            max: 1,
            divisions: 20,
            label: _temperature.toStringAsFixed(2),
            onChanged: (value) => setState(() => _temperature = value),
          ),
        ],
      ),
    );
  }

  Widget _buildKnowledgeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _useMemory,
            title: Text(widget.tx('agents.field_use_memory', 'Usar memoria')),
            onChanged: (value) => setState(() => _useMemory = value),
          ),
          if (_useMemory) ...[
            _loadingMemory
                ? const LinearProgressIndicator(minHeight: 2)
                : Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _memoryFileController,
                          decoration: InputDecoration(
                            labelText: widget.tx(
                              'agents.field_memory_file',
                              'Archivo de memoria',
                            ),
                          ),
                        ),
                      ),
                      if (_memoryFiles.isNotEmpty)
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.folder_open_outlined),
                          tooltip: widget.tx(
                            'agents.pick_existing',
                            'Elegir existente',
                          ),
                          onSelected: (value) => setState(
                            () => _memoryFileController.text = value,
                          ),
                          itemBuilder: (context) => _memoryFiles
                              .map(
                                (file) => PopupMenuItem<String>(
                                  value: file.filename,
                                  child: Text(file.filename),
                                ),
                              )
                              .toList(),
                        ),
                    ],
                  ),
          ],
          const SizedBox(height: 20),
          Text(
            widget.tx('agents.field_skills', 'Skills'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          _loadingSkills
              ? const LinearProgressIndicator(minHeight: 2)
              : _skills.isEmpty
              ? Text(
                  widget.tx('agents.no_skills', 'No hay skills disponibles.'),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _skills.map((skill) {
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedSkillIds.contains(skill.id),
                        title: Text(skill.name),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedSkillIds = {
                                ..._selectedSkillIds,
                                skill.id,
                              };
                            } else {
                              _selectedSkillIds = {..._selectedSkillIds}
                                ..remove(skill.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
          const SizedBox(height: 20),
          Text(
            widget.tx('agents.field_knowledge', 'Conocimiento'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 6),
          _loadingKnowledge
              ? const LinearProgressIndicator(minHeight: 2)
              : _knowledgeItems.isEmpty
              ? Text(
                  widget.tx(
                    'agents.no_knowledge',
                    'No hay contenido de conocimiento disponible.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _knowledgeItems.map((item) {
                      return CheckboxListTile(
                        dense: true,
                        value: _selectedKnowledgeIds.contains(item.id),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedKnowledgeIds = {
                                ..._selectedKnowledgeIds,
                                item.id,
                              };
                            } else {
                              _selectedKnowledgeIds = {..._selectedKnowledgeIds}
                                ..remove(item.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _agentType,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_type', 'Tipo de agente'),
            ),
            items: const [
              DropdownMenuItem(value: 'generic', child: Text('generic')),
              DropdownMenuItem(value: 'claude', child: Text('claude')),
              DropdownMenuItem(value: 'openai', child: Text('openai')),
              DropdownMenuItem(value: 'github', child: Text('github')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _agentType = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _modelController,
            decoration: InputDecoration(
              labelText: widget.tx('agents.field_model', 'Modelo (opcional)'),
            ),
          ),
        ],
      ),
    );
  }
}
