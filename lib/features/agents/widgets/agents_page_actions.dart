part of '../pages/agents_page.dart';

extension _AgentsPageActions on _AgentsPageState {
  Future<void> _shareAgent(AgentItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'agent',
      resourceId: item.id,
      localeController: _services.localeController,
      onShared: _load,
    );
  }

  Future<void> _showHistory(AgentItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showResourceHistoryDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'agent',
      resourceId: item.id,
      localeController: _services.localeController,
      onRestored: _load,
    );
  }

  Future<void> _openCreateDialog() async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => AgentFormPage(
          apiClient: _services.apiClient,
          token: token,
          tx: _tx,
          resourceCatalog: _agentResourceCatalog,
          resourcePageLoader: _loadAgentResourcePage,
        ),
      ),
    );
    if (payload == null) return;
    await _saveAgent(payload);
  }

  Future<void> _openCreateChoiceDialog() async {
    final choice = await showAppDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_tx('agents.create_choice_title')),
        children: [
          _createChoiceOption(
            context,
            icon: Icons.edit_note_outlined,
            title: _tx('agents.create_choice_scratch'),
            subtitle: _tx('agents.create_choice_scratch_desc'),
            value: 'scratch',
          ),
          _createChoiceOption(
            context,
            icon: Icons.upload_file_outlined,
            title: _tx('agents.create_choice_file'),
            subtitle: _tx('agents.create_choice_file_desc'),
            value: 'file',
          ),
          _createChoiceOption(
            context,
            icon: Icons.folder_open_outlined,
            title: _tx('agents.create_choice_directory'),
            subtitle: _tx('agents.create_choice_directory_desc'),
            value: 'directory',
          ),
          _createChoiceOption(
            context,
            icon: Icons.public,
            title: _tx('agents.create_choice_public'),
            subtitle: _tx('agents.create_choice_public_desc'),
            value: 'public',
          ),
          _createChoiceOption(
            context,
            icon: Icons.auto_awesome_outlined,
            title: _tx('agents.create_choice_ai'),
            subtitle: _tx('agents.create_choice_ai_desc'),
            value: 'ai',
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'scratch':
        await _openCreateDialog();
      case 'file':
        await _pickAgentFile();
      case 'directory':
        await _pickAgentDirectory();
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
    final exploreRepository = ExploreRepository(apiClient: _services.apiClient);
    List<ExploreItem> publicAgents;
    try {
      publicAgents = await exploreRepository.listResources(
        token,
        type: 'agent',
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
      return;
    } catch (_) {
      showMessage(_tx('agents.create_public_load_error'), isError: true);
      return;
    }
    if (!mounted) return;
    if (publicAgents.isEmpty) {
      showMessage(_tx('agents.create_public_empty'));
      return;
    }

    final selected = await Navigator.of(context).push<ExploreItem>(
      MaterialPageRoute(
        builder: (context) =>
            PublicAgentPickerPage(agents: publicAgents, tx: _tx),
      ),
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
      showMessage(error.message, isError: true);
      return;
    } catch (_) {
      showMessage(_tx('agents.create_public_load_error'), isError: true);
      return;
    }
    if (!mounted) return;

    final template = <String, dynamic>{
      'name':
          '${selected.name} '
          '(${_tx('agents.create_public_copy_suffix')})',
      'description': selected.description,
      'system_prompt': preview['system_prompt'] ?? '',
      'agent_type': preview['agent_type'] ?? 'generic',
      'temperature': preview['temperature'],
      'labels': ['private'],
    };

    final currentToken = _token;
    if (currentToken == null) return;
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => AgentFormPage(
          apiClient: _services.apiClient,
          token: currentToken,
          initial: template,
          tx: _tx,
          resourceCatalog: _agentResourceCatalog,
          resourcePageLoader: _loadAgentResourcePage,
        ),
      ),
    );
    if (payload == null) return;
    await _saveAgent(payload);
  }

  Future<void> _openEditDialog(AgentItem item) async {
    if (item.readOnly) {
      showMessage(_tx('agents.msg_not_editable'));
      return;
    }

    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _repository.getAgent(token, item.id);
    } catch (_) {}

    if (!mounted) return;
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => AgentFormPage(
          apiClient: _services.apiClient,
          token: token,
          initial: initial,
          tx: _tx,
          resourceCatalog: _agentResourceCatalog,
          resourcePageLoader: _loadAgentResourcePage,
        ),
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
      showMessage(_tx('agents.msg_saved'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('agents.msg_save_failed'), isError: true);
    }
  }

  Future<void> _deleteAgent(AgentItem item) async {
    if (item.readOnly) {
      showMessage(_tx('agents.msg_not_deletable'));
      return;
    }

    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('agents.delete_dialog_title'),
      message: _tx('common.delete_confirm_body')
          .replaceAll('{{nombre}}', item.name),
      cancelLabel: _tx('common.cancel'),
      confirmLabel: _tx('common.delete'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.deleteAgent(token, item.id);
      showMessage(_tx('agents.msg_deleted'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('agents.msg_delete_failed'), isError: true);
    }
  }

  Future<void> _toggleAgentActive(AgentItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final activate = !item.isActive;
    try {
      await _repository.setAgentActive(token, item.id, activate);
      showMessage(
        _tx(activate ? 'agents.msg_activated' : 'agents.msg_deactivated'),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('agents.msg_toggle_failed'), isError: true);
    }
  }

  Future<void> _exportAgent(AgentItem item, String format) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final result = await _repository.exportAgent(token, item.id, format);
      await FilePicker.saveFile(
        dialogTitle: _tx('agents.export_dialog_title'),
        fileName: result.filename ?? '${item.id}-$format.zip',
        bytes: result.bytes,
        type: FileType.custom,
        allowedExtensions: const ['zip'],
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('agents.export_error'), isError: true);
    }
  }

  Future<void> _openChat(AgentItem item) async {
    if (!item.isActive) {
      showMessage(_tx('agents.chat_inactive'), isError: true);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatPage(
          agent: item,
          apiClient: _services.apiClient,
          sessionController: _services.sessionController,
          localeController: _services.localeController,
          executionStateController: _executionState,
        ),
      ),
    );
    // Al volver del chat, refresca la tarjeta: los tokens consumidos se
    // actualizan en el agente durante la conversación y solo llegan al listado
    // con un nuevo fetch.
    await _load();
  }

  Future<void> _openAgentBuilder() async {
    // El listado se refresca solo: crear el agente pasa por la API y eso
    // avisa a las vistas que miran «agents».
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => AgentBuilderPage(
          apiClient: _services.apiClient,
          sessionController: _services.sessionController,
          localeController: _services.localeController,
        ),
      ),
    );
  }
}
