import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/async_state_panel.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/agents/agent_models.dart';
import '../../../models/explore/explore_models.dart';
import '../../explore/repositories/explore_repository.dart';
import '../cards/agent_card.dart';
import '../repositories/agents_repository.dart';
import '../dialogs/agent_form_dialog.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/buttons/filter_button.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/group_filter_panel.dart';
import 'agent_builder_page.dart';
import '../../../shared/widgets/resource_history_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/share_to_group_dialog.dart';
import 'chat_page.dart';

part '../dialogs/public_agent_picker_dialog.dart';
part '../widgets/agents_page_view.dart';

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

  Future<void> _openCreateChoiceDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          _tx('agents.create_choice_title', '¿Cómo quieres crear el agente?'),
        ),
        children: [
          _createChoiceOption(
            context,
            icon: Icons.edit_note_outlined,
            title: _tx('agents.create_choice_scratch', 'Desde cero'),
            subtitle: _tx(
              'agents.create_choice_scratch_desc',
              'Un formulario en blanco, tú decides cada campo.',
            ),
            value: 'scratch',
          ),
          _createChoiceOption(
            context,
            icon: Icons.public,
            title: _tx(
              'agents.create_choice_public',
              'A partir de un agente público',
            ),
            subtitle: _tx(
              'agents.create_choice_public_desc',
              'Parte de uno ya existente como plantilla y edítalo.',
            ),
            value: 'public',
          ),
          _createChoiceOption(
            context,
            icon: Icons.auto_awesome_outlined,
            title: _tx('agents.create_choice_ai', 'Con ayuda de IA'),
            subtitle: _tx(
              'agents.create_choice_ai_desc',
              'Descríbelo en una conversación y te propone un borrador.',
            ),
            value: 'ai',
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'scratch':
        await _openCreateDialog();
      case 'public':
        await _openCreateFromPublicDialog();
      case 'ai':
        await _openAgentBuilder();
    }
  }

  Widget _createChoiceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateFromPublicDialog() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    // Los agentes públicos de CUALQUIER usuario se descubren vía Explore
    // (/api/agents?scope=X para un usuario normal solo devuelve los tuyos).
    final exploreRepository = ExploreRepository(apiClient: widget.apiClient);
    List<ExploreItem> publicAgents;
    try {
      publicAgents = await exploreRepository.listResources(
        token,
        type: 'agent',
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
      return;
    } catch (_) {
      _showMessage(
        _tx(
          'agents.create_public_load_error',
          'No se pudieron cargar los agentes públicos',
        ),
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    if (publicAgents.isEmpty) {
      _showMessage(
        _tx(
          'agents.create_public_empty',
          'No hay agentes públicos disponibles todavía',
        ),
      );
      return;
    }

    final selected = await showDialog<ExploreItem>(
      context: context,
      builder: (context) =>
          _PublicAgentPickerDialog(agents: publicAgents, tx: _tx),
    );
    if (selected == null || !mounted) return;

    Map<String, dynamic> preview;
    try {
      preview = await exploreRepository.getPreview(
        token,
        resourceType: 'agent',
        resourceId: selected.resourceId,
      );
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
      return;
    } catch (_) {
      _showMessage(
        _tx(
          'agents.create_public_load_error',
          'No se pudieron cargar los agentes públicos',
        ),
        isError: true,
      );
      return;
    }
    if (!mounted) return;

    final template = <String, dynamic>{
      'name':
          '${selected.name} '
          '(${_tx('agents.create_public_copy_suffix', 'copia')})',
      'description': selected.description,
      'system_prompt': preview['system_prompt'] ?? '',
      'agent_type': preview['agent_type'] ?? 'generic',
      'temperature': preview['temperature'],
      'labels': ['private'],
    };

    final currentToken = _token;
    if (currentToken == null) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AgentFormDialog(
        apiClient: widget.apiClient,
        token: currentToken,
        initial: template,
        tx: _tx,
      ),
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

    final confirm = await showConfirmActionDialog(
      context,
      title: 'Eliminar agente',
      message: '¿Seguro que quieres eliminar "${item.name}"?',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Eliminar',
    );
    if (!confirm) return;

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

  void _refresh(VoidCallback update) => setState(update);

  @override
  Widget build(BuildContext context) => _buildPage(context);
}
