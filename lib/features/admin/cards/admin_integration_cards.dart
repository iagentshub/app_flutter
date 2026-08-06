part of '../pages/admin_page.dart';

extension _AdminIntegrationCards on _AdminPageState {
  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final name = (agent['name'] ?? agent['id'] ?? '').toString();
    final type = (agent['agent_type'] ?? '—').toString();
    final owner = _ownerOf(agent);
    final connId = (agent['connection_id'] ?? '').toString();
    final scope = (agent['scope'] ?? 'private').toString();
    final tokens = _asInt(agent['tokens_in']) + _asInt(agent['tokens_out']);
    final date = _fmtDate(agent['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${owner.isEmpty ? '—' : owner}${connId.isEmpty ? '' : ' · $connId'} · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _resourceTypeBadge(AdminResourceType.agent),
                _badge(type, FncColors.slate),
                _badge(scope, labelColor(scope)),
                if (tokens > 0) _badge(_fmtTokens(tokens), FncColors.info),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                _resourceGraphAction(AdminResourceType.agent, agent),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditAgentDialog(agent),
                ),
                ActionIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: _tx(
                    'admin.action_change_owner',
                    'Cambiar propietario',
                  ),
                  onPressed: () => _changeOwner(agent, 'agent'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteAgent(agent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminConnectionCard(Map<String, dynamic> conn) {
    final name = (conn['name'] ?? conn['id'] ?? '').toString();
    final type = (conn['type'] ?? '—').toString();
    final owner = _ownerOf(conn);
    final tokens = _asInt(conn['tokens_in']) + _asInt(conn['tokens_out']);
    final date = _fmtDate(conn['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${owner.isEmpty ? '—' : owner} · $date',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _resourceTypeBadge(AdminResourceType.connection),
                _badge(type, FncColors.slate),
                if (tokens > 0) _badge(_fmtTokens(tokens), FncColors.info),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                _resourceGraphAction(AdminResourceType.connection, conn),
                ActionIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: _tx(
                    'admin.action_change_owner',
                    'Cambiar propietario',
                  ),
                  onPressed: () => _changeOwner(conn, 'connection'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteConnection(conn),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab: Conocimiento ────────────────────────────────────────────────
