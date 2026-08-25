part of '../pages/admin_page.dart';

extension _AdminActions on _AdminPageState {
  Future<void> _toggleUserActive(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final active = user['is_active'] != 0 && user['is_active'] != false;
    await _run(
      () => _usersRepository.setUserActive(token, username, !active),
      active
          ? _tx('admin.toast_user_blocked')
          : _tx('admin.toast_user_unblocked'),
    );
  }

  Future<void> _promoteUser(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final ok = await _confirm(
      _tx('admin.action_make_admin'),
      _tx('admin.confirm_promote').replaceAll('{username}', username),
      confirmLabel: _tx('admin.action_make_admin'),
      destructive: false,
    );
    if (!ok) return;
    await _run(
      () => _usersRepository.patchUser(token, username, role: 'admin'),
      _tx('admin.toast_user_promoted'),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_user').replaceAll('{username}', username),
    );
    if (!ok) return;
    await _run(
      () => _usersRepository.deleteUser(token, username),
      _tx('admin.toast_user_deleted'),
    );
  }

  Future<void> _openEditUserDialog(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final result = await showAppDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserEditDialog(user: user, tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _usersRepository.patchUser(
        token,
        username,
        role: result['role'] as String?,
        isActive: result['is_active'] as bool?,
        password: (result['password'] as String?)?.isEmpty == true
            ? null
            : result['password'] as String?,
      ),
      _tx('admin.toast_user_updated'),
    );
  }

  Future<void> _openCreateUserDialog() async {
    final token = _token;
    if (token == null) return;
    final result = await showAppDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserCreateDialog(tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _usersRepository.createUser(
        token,
        username: result['username'] as String,
        email: result['email'] as String,
        password: result['password'] as String,
        displayName: result['display_name'] as String?,
        role: result['role'] as String,
      ),
      _tx('admin.toast_user_created'),
    );
  }

  // ── Acciones: grupos (groups) ────────────────────────────────────

  Future<void> _toggleGroupStatus(Map<String, dynamic> group) async {
    final token = _token;
    if (token == null) return;
    final id = (group['id'] ?? '').toString();
    final name = (group['name'] ?? id).toString();
    final isDisabled = (group['status'] ?? 'active').toString() == 'disabled';
    final newStatus = isDisabled ? 'active' : 'disabled';
    if (!isDisabled) {
      final ok = await _confirm(
        _tx('admin.action_deactivate'),
        _tx('admin.confirm_deactivate_group').replaceAll('{name}', name),
        confirmLabel: _tx('admin.action_deactivate'),
        // Reversible: el grupo se puede reactivar desde el mismo sitio.
        destructive: false,
      );
      if (!ok) return;
    }
    await _run(
      () => _groupsRepository.setGroupStatus(token, id, newStatus),
      isDisabled
          ? _tx('admin.toast_group_reactivated')
          : _tx('admin.toast_group_deactivated'),
    );
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final token = _token;
    if (token == null) return;
    final id = (group['id'] ?? '').toString();
    final name = (group['name'] ?? id).toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_group').replaceAll('{name}', name),
    );
    if (!ok) return;
    await _run(
      () => _groupsRepository.deleteGroup(token, id),
      _tx('admin.toast_group_deleted'),
    );
  }

  // ── Acciones: agentes ────────────────────────────────────────────────

  Future<void> _openEditAgentDialog(Map<String, dynamic> agent) async {
    final token = _token;
    if (token == null) return;
    final id = (agent['id'] ?? '').toString();
    final result = await showAppDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AgentEditDialog(agent: agent, tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _agentsRepository.updateAgent(token, id, result),
      _tx('admin.toast_agent_updated'),
    );
  }

  Future<void> _deleteAgent(Map<String, dynamic> agent) async {
    final token = _token;
    if (token == null) return;
    final id = (agent['id'] ?? '').toString();
    final name = (agent['name'] ?? id).toString();
    final scope = (agent['scope'] ?? 'private').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_agent').replaceAll('{name}', name),
    );
    if (!ok) return;
    await _run(
      () => _agentsRepository.deleteAgent(token, id, scope: scope),
      _tx('admin.toast_agent_deleted'),
    );
  }

  // ── Acciones: conexiones / knowledge / workflows ─────────────────────

  Future<void> _deleteConnection(Map<String, dynamic> conn) async {
    final token = _token;
    if (token == null) return;
    final id = (conn['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_connection'),
    );
    if (!ok) return;
    await _run(
      () => _connectionsRepository.deleteAdminConnection(token, id),
      _tx('admin.toast_connection_deleted'),
    );
  }

  Future<void> _deleteKnowledge(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_knowledge'),
    );
    if (!ok) return;
    await _run(
      () => _knowledgeRepository.deleteAdminKnowledge(token, id),
      _tx('admin.toast_knowledge_deleted'),
    );
  }

  Future<void> _deleteWorkflow(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_workflow'),
    );
    if (!ok) return;
    await _run(
      () => _resourcesRepository.deleteAdminWorkflow(token, id),
      _tx('admin.toast_workflow_deleted'),
    );
  }

  Future<void> _deleteLlmOrchestration(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_llm_orchestration'),
    );
    if (!ok) return;
    await _run(
      () => _resourcesRepository.deleteAdminLlmOrchestration(token, id),
      _tx('admin.toast_llm_orchestration_deleted'),
    );
  }

  Future<void> _deleteSkill(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_skill'),
    );
    if (!ok) return;
    await _run(
      () => _resourcesRepository.deleteAdminSkill(token, id),
      _tx('admin.toast_skill_deleted'),
    );
  }

  Future<void> _deletePrompt(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_prompt'),
    );
    if (!ok) return;
    await _run(
      () => _resourcesRepository.deleteAdminPrompt(token, id),
      _tx('admin.toast_prompt_deleted'),
    );
  }

  Future<void> _deleteTool(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_tool'),
    );
    if (!ok) return;
    await _run(
      () => _resourcesRepository.deleteAdminTool(token, id),
      _tx('admin.toast_tool_deleted'),
    );
  }

  Future<void> _setToolSecurity(Map<String, dynamic> item, String state) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    if (state == 'approved') {
      try {
        final detail = await _resourcesRepository.getAdminTool(token, id);
        if (!mounted) return;
        final source = (detail['content'] ?? '').toString();
        final instructions = (detail['instructions'] ?? '').toString();
        final sha256 = (detail['binary_sha256'] ?? '').toString();
        final accepted = await showAppDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_tx('official.review_tool')),
            content: SizedBox(
              width: dialogContentWidth(context, 700),
              child: SingleChildScrollView(
                child: SelectableText(
                  [
                    if (instructions.isNotEmpty) instructions,
                    if (source.isNotEmpty) source,
                    if (sha256.isNotEmpty) 'SHA-256: $sha256',
                  ].join('\n\n'),
                  style: const TextStyle(fontFamily: FncFonts.monospace),
                ),
              ),
            ),
            actions: [
              TertiaryButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(_tx('common.cancel')),
              ),
              PrimaryButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(_tx('official.reviewed')),
              ),
            ],
          ),
        );
        if (accepted != true) return;
      } on ApiError catch (error) {
        showMessage(error.message, isError: true);
        return;
      }
    }
    await _run(
      () => _resourcesRepository.setAdminToolSecurity(token, id, state),
      state == 'approved'
          ? _tx('official.reviewed')
          : trOr('labels.$state', state),
    );
  }

  Future<void> _deleteMemory(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete'),
      _tx('admin.confirm_delete_memory'),
    );
    if (!ok) return;
    await _run(
      () => _resourcesRepository.deleteAdminMemory(token, id),
      _tx('admin.toast_memory_deleted'),
    );
  }

  // ── Acciones: cambiar propietario (agentes/conexiones/knowledge/orquest.) ─

  Future<void> _changeOwner(
    Map<String, dynamic> item,
    String resourceType,
  ) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final currentOwner = _ownerOf(item);
    final usernames =
        _users
            .map((u) => (u['username'] ?? '').toString())
            .where((u) => u.isNotEmpty && u != currentOwner)
            .toList()
          ..sort();
    final newOwner = await showAppDialog<String>(
      context: context,
      builder: (context) => _OwnerPickerDialog(
        currentOwner: currentOwner,
        usernames: usernames,
        tx: _tx,
      ),
    );
    if (newOwner == null || newOwner.isEmpty) return;
    await _run(
      () => _resourcesRepository.setResourceOwner(
        token,
        resourceType,
        id,
        newOwner,
      ),
      _tx('admin.toast_owner_changed'),
    );
  }

  /// Marca o desmarca a mano un recurso como oficial. No lo mueve de sitio ni
  /// cambia de dueño: solo le pone la fuente interna, que es lo que hace que
  /// se vea con la etiqueta `official`.
  Future<void> _toggleOfficial(
    Map<String, dynamic> item,
    String resourceType,
  ) async {
    final token = _token;
    if (token == null) return;
    final official = _isOfficial(item);
    await _run(
      () => _officialSourcesRepository.markOfficial(
        token,
        resourceType: resourceType,
        resourceId: (item['id'] ?? '').toString(),
        official: !official,
      ),
      official
          ? _tx('admin.toast_official_removed')
          : _tx('admin.toast_official_set'),
    );
  }

  bool _isOfficial(Map<String, dynamic> item) {
    final labels = item['labels'];
    return labels is List &&
        labels.map((e) => e.toString()).contains('official');
  }

  Widget _officialAction(Map<String, dynamic> item, String resourceType) {
    final official = _isOfficial(item);
    return ActionIconButton(
      icon: official ? Icons.verified : Icons.verified_outlined,
      tooltip: official
          ? _tx('admin.action_unset_official')
          : _tx('admin.action_set_official'),
      onPressed: () => _toggleOfficial(item, resourceType),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────
}
