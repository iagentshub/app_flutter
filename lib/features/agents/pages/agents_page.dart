import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/agents/agent_models.dart';
import '../repositories/agents_repository.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import 'chat_page.dart';

class AgentsPage extends StatefulWidget {
  const AgentsPage({
    required this.apiClient,
    required this.sessionController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  late final AgentsRepository _repository;
  final TextEditingController _queryController = TextEditingController();
  List<AgentItem> _agents = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _activeGroupId;

  List<AgentItem> get _filteredAgents {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return _agents;
    return _agents.where((item) {
      return item.name.toLowerCase().contains(query) ||
          item.agentType.toLowerCase().contains(query) ||
          item.model.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _repository = AgentsRepository(apiClient: widget.apiClient);
    _load();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final agents = await _repository.listAgents(token, groupId: _activeGroupId);
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
        _error = 'No se pudieron cargar los agentes';
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
      onShared: _load,
    );
  }

  Future<void> _openCreateDialog() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _AgentFormDialog(),
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
      builder: (context) => _AgentFormDialog(initial: initial),
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
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
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
                  const Text('Error cargando agentes', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 700;
        final groupPanel = GroupFilterPanel(
          apiClient: widget.apiClient,
          token: _token ?? '',
          activeGroupId: _activeGroupId,
          onSelect: _onGroupSelect,
          vertical: wide,
        );

        final list = RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _openCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Nuevo agente'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar'),
                  ),
                ],
              ),
              if (!wide) ...[
                const SizedBox(height: 12),
                groupPanel,
              ],
              const SizedBox(height: 12),
              TextField(
                controller: _queryController,
                decoration: const InputDecoration(
                  labelText: 'Buscar agente',
                  prefixIcon: Icon(Icons.search, size: 20),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 12),
              Text('Agentes: ${_filteredAgents.length}', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 12),
              if (_filteredAgents.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_agents.isEmpty ? 'No hay agentes disponibles.' : 'Sin resultados para esa búsqueda.'),
                  ),
                )
              else
                ..._filteredAgents.map(_buildAgentCard),
            ],
          ),
        );

        if (!wide) return list;
        return Row(
          children: [
            groupPanel,
            Expanded(child: list),
          ],
        );
      },
    );
  }

  Widget _buildAgentCard(AgentItem item) {
    final subtitleParts = <String>[item.agentType];
    if (item.model.isNotEmpty) subtitleParts.add(item.model);
    if (item.connectionId.isNotEmpty) subtitleParts.add('conn: ${item.connectionId}');

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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                _chip(item.scope),
                if (item.shared) _chip('shared'),
              ],
            ),
            const SizedBox(height: 6),
            Text(subtitleParts.join(' · ')),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(item.description, maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _openChat(item),
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Chat'),
                ),
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: 'Compartir con grupo',
                  onPressed: () => _shareAgent(item),
                ),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Editar',
                  onPressed: () => _openEditDialog(item),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: 'Eliminar',
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

  Widget _chip(String text) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _AgentFormDialog extends StatefulWidget {
  const _AgentFormDialog({this.initial});

  final Map<String, dynamic>? initial;

  @override
  State<_AgentFormDialog> createState() => _AgentFormDialogState();
}

class _AgentFormDialogState extends State<_AgentFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _modelController;
  late final TextEditingController _connectionIdController;
  late final TextEditingController _promptController;
  late final TextEditingController _temperatureController;
  late final TextEditingController _labelsController;

  String _scope = 'private';
  String _agentType = 'generic';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?['name']?.toString() ?? '');
    _descriptionController = TextEditingController(text: initial?['description']?.toString() ?? '');
    _modelController = TextEditingController(text: initial?['model']?.toString() ?? '');
    _connectionIdController = TextEditingController(text: initial?['connection_id']?.toString() ?? '');
    _promptController = TextEditingController(text: initial?['system_prompt']?.toString() ?? '');
    _temperatureController = TextEditingController(text: initial?['temperature']?.toString() ?? '0.7');

    final labelsRaw = initial?['labels'];
    if (labelsRaw is List) {
      _labelsController = TextEditingController(text: labelsRaw.join(', '));
    } else {
      _labelsController = TextEditingController(text: 'private');
    }

    _scope = (initial?['scope'] as String?) ?? 'private';
    _agentType = (initial?['agent_type'] as String?) ?? 'generic';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _modelController.dispose();
    _connectionIdController.dispose();
    _promptController.dispose();
    _temperatureController.dispose();
    _labelsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final labels = _labelsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'scope': _scope,
      'agent_type': _agentType,
      'model': _modelController.text.trim(),
      'connection_id': _connectionIdController.text.trim(),
      'system_prompt': _promptController.text.trim(),
      'temperature': num.tryParse(_temperatureController.text.trim()) ?? 0.7,
      'labels': labels,
    };

    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nuevo agente' : 'Editar agente'),
      content: SizedBox(
        width: 580,
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'El nombre es obligatorio';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Scope'),
                items: const [
                  DropdownMenuItem(value: 'private', child: Text('private')),
                  DropdownMenuItem(value: 'public', child: Text('public')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _scope = value);
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _agentType,
                decoration: const InputDecoration(labelText: 'Tipo de agente'),
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
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _modelController,
                decoration: const InputDecoration(labelText: 'Modelo'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _connectionIdController,
                decoration: const InputDecoration(labelText: 'Connection ID'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _temperatureController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Temperatura'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _labelsController,
                decoration: const InputDecoration(labelText: 'Labels (coma separada)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _promptController,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'System prompt'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
