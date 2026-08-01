part of '../pages/admin_page.dart';

extension _AdminPeopleCards on _AdminPageState {
  Widget _buildUsersTab() {
    final showNewUser =
        (_platformSettings?['registration'] ?? 'open').toString() == 'closed';
    return _buildFilterableList(
      items: _filteredUsers,
      itemBuilder: _buildUserCard,
      emptyText: _tx('admin.users_empty', 'Sin usuarios para ese filtro'),
      toolbar: _toolbar(
        search: TextField(
          controller: _userSearchController,
          decoration: InputDecoration(
            labelText: _tx(
              'admin.users_search_hint',
              'Buscar por email o usuario',
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => _onSearchChanged(),
        ),
        buttons: [
          if (showNewUser)
            AppIconButton.filled(
              onPressed: _openCreateUserDialog,
              icon: const Icon(Icons.add),
              tooltip: _tx('admin.users_new_btn', 'Nuevo usuario'),
            ),
          AppIconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
          FilterButton(
            activeCount: _usersActiveFilterCount,
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: _openUsersFiltersDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final email = (user['email'] ?? user['username'] ?? '').toString();
    final role = (user['role'] ?? 'standard').toString();
    final isAdmin = role == 'admin';
    final active = user['is_active'] != 0 && user['is_active'] != false;
    final verified = user['is_verified'] != 0 && user['is_verified'] != false;
    final tokens = _asInt(user['tokens_in']) + _asInt(user['tokens_out']);
    final date = _fmtDate(user['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    email,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(
                  isAdmin
                      ? _tx('admin.role_admin', 'Admin')
                      : _tx('admin.role_standard', 'Estándar'),
                  isAdmin ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
                ),
                _badge(
                  active
                      ? _tx('admin.status_active', 'Activo')
                      : _tx('admin.status_blocked', 'Bloqueado'),
                  active ? const Color(0xFF059669) : const Color(0xFFDC2626),
                ),
                _badge(
                  verified
                      ? _tx('admin.verified_yes', 'Verificado')
                      : _tx('admin.verified_no', 'Sin verificar'),
                  verified ? const Color(0xFF059669) : const Color(0xFFD97706),
                ),
                if (tokens > 0)
                  _badge(_fmtTokens(tokens), const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 6),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditUserDialog(user),
                ),
                ActionIconButton(
                  icon: active
                      ? Icons.block_outlined
                      : Icons.check_circle_outline,
                  tooltip: active
                      ? _tx('admin.action_block', 'Bloquear')
                      : _tx('admin.action_unblock', 'Desbloquear'),
                  onPressed: () => _toggleUserActive(user),
                ),
                if (!isAdmin)
                  ActionIconButton(
                    icon: Icons.shield_outlined,
                    tooltip: _tx('admin.action_make_admin', 'Hacer admin'),
                    onPressed: () => _promoteUser(user),
                  ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteUser(user),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Grupos ──────────────────────────────────────────────────────

  Widget _buildGroupsTab() {
    return _buildFilterableList(
      items: _filteredGroups,
      itemBuilder: _buildGroupCard,
      emptyText: _tx('admin.group_empty', 'Sin grupos'),
      toolbar: _toolbar(
        search: TextField(
          controller: _groupSearchController,
          decoration: InputDecoration(
            labelText: _tx(
              'admin.group_search_hint',
              'Buscar por nombre o creador',
            ),
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
          onChanged: (_) => _onSearchChanged(),
        ),
        buttons: [
          AppIconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final name = (group['name'] ?? group['id'] ?? '').toString();
    final disabled = (group['status'] ?? 'active').toString() == 'disabled';
    final creator = (group['created_by_username'] ?? '—').toString();
    final members = _asInt(group['member_count']);
    final connections = _asInt(group['connections_count']);
    final agents = _asInt(group['agents_count']);
    final knowledge = _asInt(group['knowledge_count']);
    final tokens = _asInt(group['tokens_in']) + _asInt(group['tokens_out']);
    final date = _fmtDate(group['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _badge(
                  disabled
                      ? _tx('admin.status_disabled', 'Desactivado')
                      : _tx('admin.status_active', 'Activo'),
                  disabled ? const Color(0xFFDC2626) : const Color(0xFF059669),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_tx('admin.table_creator', 'Creador')}: $creator · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _badge(
                  '${_tx('admin.table_members', 'Miembros')}: $members',
                  const Color(0xFF64748B),
                ),
                _badge(
                  '${_tx('admin.tab_connections', 'Conexiones')}: $connections',
                  const Color(0xFF64748B),
                ),
                _badge(
                  '${_tx('admin.tab_agents', 'Agentes')}: $agents',
                  const Color(0xFF64748B),
                ),
                _badge(
                  '${_tx('admin.tab_knowledge', 'Conocimiento')}: $knowledge',
                  const Color(0xFF64748B),
                ),
                if (tokens > 0)
                  _badge(_fmtTokens(tokens), const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: disabled
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                  tooltip: disabled
                      ? _tx('admin.action_reactivate', 'Reactivar')
                      : _tx('admin.action_deactivate', 'Desactivar'),
                  onPressed: () => _toggleGroupStatus(group),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteGroup(group),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Agentes ─────────────────────────────────────────────────────
