part of '../pages/admin_page.dart';

extension _AdminActions on _AdminPageState {
  Future<void> _toggleUserActive(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final active = user['is_active'] != 0 && user['is_active'] != false;
    await _run(
      () => _repository.setUserActive(token, username, !active),
      active
          ? _tx('admin.toast_user_blocked', 'Usuario bloqueado')
          : _tx('admin.toast_user_unblocked', 'Usuario desbloqueado'),
    );
  }

  Future<void> _promoteUser(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final ok = await _confirm(
      _tx('admin.action_make_admin', 'Hacer admin'),
      _tx(
        'admin.confirm_promote',
        '¿Ascender a "{username}" a administrador?',
      ).replaceAll('{username}', username),
      confirmLabel: _tx('admin.action_make_admin', 'Hacer admin'),
    );
    if (!ok) return;
    await _run(
      () => _repository.patchUser(token, username, role: 'admin'),
      _tx('admin.toast_user_promoted', 'Usuario ascendido a admin'),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_user',
        '¿Seguro que quieres eliminar al usuario "{username}"?',
      ).replaceAll('{username}', username),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteUser(token, username),
      _tx('admin.toast_user_deleted', 'Usuario eliminado'),
    );
  }

  Future<void> _openEditUserDialog(Map<String, dynamic> user) async {
    final token = _token;
    if (token == null) return;
    final username = (user['username'] ?? '').toString();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserEditDialog(user: user, tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _repository.patchUser(
        token,
        username,
        role: result['role'] as String?,
        isActive: result['is_active'] as bool?,
        password: (result['password'] as String?)?.isEmpty == true
            ? null
            : result['password'] as String?,
      ),
      _tx('admin.toast_user_updated', 'Usuario actualizado'),
    );
  }

  Future<void> _openCreateUserDialog() async {
    final token = _token;
    if (token == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _UserCreateDialog(tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _repository.createUser(
        token,
        username: result['username'] as String,
        email: result['email'] as String,
        password: result['password'] as String,
        displayName: result['display_name'] as String?,
        role: result['role'] as String,
      ),
      _tx('admin.toast_user_created', 'Usuario creado'),
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
        _tx('admin.action_deactivate', 'Desactivar'),
        _tx(
          'admin.confirm_deactivate_group',
          '¿Desactivar el grupo "{name}"?',
        ).replaceAll('{name}', name),
        confirmLabel: _tx('admin.action_deactivate', 'Desactivar'),
      );
      if (!ok) return;
    }
    await _run(
      () => _repository.setGroupStatus(token, id, newStatus),
      isDisabled
          ? _tx('admin.toast_group_reactivated', 'Grupo reactivado')
          : _tx('admin.toast_group_deactivated', 'Grupo desactivado'),
    );
  }

  Future<void> _deleteGroup(Map<String, dynamic> group) async {
    final token = _token;
    if (token == null) return;
    final id = (group['id'] ?? '').toString();
    final name = (group['name'] ?? id).toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_group',
        '¿Seguro que quieres eliminar el grupo "{name}"?',
      ).replaceAll('{name}', name),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteGroup(token, id),
      _tx('admin.toast_group_deleted', 'Grupo eliminado'),
    );
  }

  // ── Acciones: agentes ────────────────────────────────────────────────

  Future<void> _openEditAgentDialog(Map<String, dynamic> agent) async {
    final token = _token;
    if (token == null) return;
    final id = (agent['id'] ?? '').toString();
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AgentEditDialog(agent: agent, tx: _tx),
    );
    if (result == null) return;
    await _run(
      () => _repository.updateAgent(token, id, result),
      _tx('admin.toast_agent_updated', 'Agente actualizado'),
    );
  }

  Future<void> _deleteAgent(Map<String, dynamic> agent) async {
    final token = _token;
    if (token == null) return;
    final id = (agent['id'] ?? '').toString();
    final name = (agent['name'] ?? id).toString();
    final scope = (agent['scope'] ?? 'private').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_agent',
        '¿Seguro que quieres eliminar el agente "{name}"?',
      ).replaceAll('{name}', name),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteAgent(token, id, scope: scope),
      _tx('admin.toast_agent_deleted', 'Agente eliminado'),
    );
  }

  // ── Acciones: conexiones / knowledge / workflows ─────────────────────

  Future<void> _deleteConnection(Map<String, dynamic> conn) async {
    final token = _token;
    if (token == null) return;
    final id = (conn['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_connection',
        '¿Seguro que quieres eliminar esta conexión?',
      ),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteAdminConnection(token, id),
      _tx('admin.toast_connection_deleted', 'Conexión eliminada'),
    );
  }

  Future<void> _deleteKnowledge(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_knowledge',
        '¿Seguro que quieres eliminar este elemento?',
      ),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteAdminKnowledge(token, id),
      _tx('admin.toast_knowledge_deleted', 'Elemento eliminado'),
    );
  }

  Future<void> _deleteWorkflow(Map<String, dynamic> item) async {
    final token = _token;
    if (token == null) return;
    final id = (item['id'] ?? '').toString();
    final ok = await _confirm(
      _tx('common.delete', 'Eliminar'),
      _tx(
        'admin.confirm_delete_workflow',
        '¿Seguro que quieres eliminar esta orquestación?',
      ),
    );
    if (!ok) return;
    await _run(
      () => _repository.deleteAdminWorkflow(token, id),
      _tx('admin.toast_workflow_deleted', 'Orquestación eliminada'),
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
    final newOwner = await showDialog<String>(
      context: context,
      builder: (context) => _OwnerPickerDialog(
        currentOwner: currentOwner,
        usernames: usernames,
        tx: _tx,
      ),
    );
    if (newOwner == null || newOwner.isEmpty) return;
    await _run(
      () => _repository.setResourceOwner(token, resourceType, id, newOwner),
      _tx('admin.toast_owner_changed', 'Propietario actualizado'),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────
}
