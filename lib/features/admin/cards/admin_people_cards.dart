part of '../pages/admin_page.dart';

extension _AdminPeopleCards on _AdminPageState {
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
                _resourceTypeBadge(AdminResourceType.user),
                _badge(
                  isAdmin
                      ? _tx('admin.role_admin')
                      : _tx('admin.role_standard'),
                  isAdmin ? FncColors.purple : FncColors.slate,
                ),
                _badge(
                  active
                      ? _tx('admin.status_active')
                      : _tx('admin.status_blocked'),
                  active ? FncColors.success : FncColors.danger,
                ),
                _badge(
                  verified
                      ? _tx('admin.verified_yes')
                      : _tx('admin.verified_no'),
                  verified ? FncColors.success : FncColors.labelDevelopment,
                ),
                if (tokens > 0) _badge(_fmtTokens(tokens), FncColors.info),
              ],
            ),
            const SizedBox(height: 6),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                _resourceGraphAction(AdminResourceType.user, user),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit'),
                  onPressed: () => _openEditUserDialog(user),
                ),
                ActionIconButton(
                  icon: active
                      ? Icons.block_outlined
                      : Icons.check_circle_outline,
                  tooltip: active
                      ? _tx('admin.action_block')
                      : _tx('admin.action_unblock'),
                  onPressed: () => _toggleUserActive(user),
                ),
                if (!isAdmin)
                  ActionIconButton(
                    icon: Icons.shield_outlined,
                    tooltip: _tx('admin.action_make_admin'),
                    onPressed: () => _promoteUser(user),
                  ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete'),
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
                      fontSize: FncFonts.size16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _badge(
                  disabled
                      ? _tx('admin.status_disabled')
                      : _tx('admin.status_active'),
                  disabled ? FncColors.danger : FncColors.success,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_tx('admin.table_creator')}: $creator · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _resourceTypeBadge(AdminResourceType.group),
                _badge(
                  '${_tx('admin.table_members')}: $members',
                  FncColors.slate,
                ),
                _badge(
                  '${_tx('admin.tab_connections')}: $connections',
                  FncColors.slate,
                ),
                _badge('${_tx('admin.tab_agents')}: $agents', FncColors.slate),
                _badge(
                  '${_tx('admin.tab_knowledge')}: $knowledge',
                  FncColors.slate,
                ),
                if (tokens > 0) _badge(_fmtTokens(tokens), FncColors.info),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                _resourceGraphAction(AdminResourceType.group, group),
                ActionIconButton(
                  icon: disabled
                      ? Icons.check_circle_outline
                      : Icons.block_outlined,
                  tooltip: disabled
                      ? _tx('admin.action_reactivate')
                      : _tx('admin.action_deactivate'),
                  onPressed: () => _toggleGroupStatus(group),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete'),
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
