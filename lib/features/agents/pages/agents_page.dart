import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/agents/agent_models.dart';
import '../repositories/agents_repository.dart';
import '../widgets/agent_form_dialog.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/filter_button.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/label_chips_row.dart';
import 'agent_builder_page.dart';
import '../../../shared/widgets/origin_badge.dart';
import '../../../shared/widgets/resource_history_dialog.dart';
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

  Future<void> _showHistory(AgentItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showResourceHistoryDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'agent',
      resourceId: item.id,
      localeController: widget.localeController,
      onRestored: _load,
    );
  }

  Future<void> _openCreateDialog() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          AgentFormDialog(apiClient: widget.apiClient, token: token, tx: _tx),
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
      builder: (context) => AgentFormDialog(
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

  Future<void> _exportAgent(AgentItem item, String format) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final result = await _repository.exportAgent(token, item.id, format);
      await FilePicker.platform.saveFile(
        dialogTitle: _tx('agents.export_dialog_title', 'Guardar exportación'),
        fileName: result.filename ?? '${item.id}-$format.zip',
        bytes: result.bytes,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('agents.export_error', 'No se pudo exportar el agente'),
        isError: true,
      );
    }
  }

  void _openChat(AgentItem item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          agent: item,
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
          localeController: widget.localeController,
        ),
      ),
    );
  }

  Future<void> _openAgentBuilder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AgentBuilderPage(
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
          localeController: widget.localeController,
        ),
      ),
    );
    if (created == true) await _load();
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
                        onPressed: _openAgentBuilder,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        tooltip: _tx(
                          'agents.builder_new',
                          'Crear agente con IA',
                        ),
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
                PopupMenuButton<String>(
                  tooltip: _tx('agents.export_tooltip', 'Exportar'),
                  icon: const Icon(Icons.ios_share_outlined, size: 18),
                  onSelected: (format) => _exportAgent(item, format),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'openai',
                      child: Text(_tx('agents.export_openai', 'OpenAI')),
                    ),
                    PopupMenuItem(
                      value: 'claude',
                      child: Text(_tx('agents.export_claude', 'Claude')),
                    ),
                    PopupMenuItem(
                      value: 'github',
                      child: Text(
                        _tx('agents.export_github', 'GitHub Copilot'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'mcp',
                      child: Text(_tx('agents.export_mcp', 'Servidor MCP')),
                    ),
                  ],
                ),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: _tx('common.share_group', 'Compartir con grupo'),
                  onPressed: () => _shareAgent(item),
                ),
                ActionIconButton(
                  icon: Icons.history,
                  tooltip: _tx(
                    'history.dialog_title',
                    'Historial de versiones',
                  ),
                  onPressed: () => _showHistory(item),
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
