part of '../pages/admin_page.dart';

extension _AdminIntegrationCards on _AdminPageState {
  Widget _buildAgentsTab() {
    return _buildFilterableList(
      items: _filteredAgents,
      itemBuilder: _buildAgentCard,
      emptyText: _tx('admin.agents_empty', 'Sin agentes'),
      toolbar: _toolbar(
        search: TextField(
          controller: _agentSearchController,
          decoration: InputDecoration(
            labelText: _tx('admin.agents_search_hint', 'Buscar agente'),
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
          FilterButton(
            activeCount: _agentOwner.isNotEmpty ? 1 : 0,
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: () => _openOwnerFilterDialog(
              owners: _ownersOf(_agents),
              currentOwner: _agentOwner,
              onChanged: (v) => _refresh(() => _agentOwner = v),
            ),
          ),
        ],
      ),
    );
  }

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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                _badge(type, const Color(0xFF64748B)),
                _badge(scope, labelColor(scope)),
                if (tokens > 0)
                  _badge(_fmtTokens(tokens), const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
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

  // ── Tab: Conexiones ──────────────────────────────────────────────────

  Widget _buildConnectionsTab() {
    return _buildFilterableList(
      items: _filteredConnections,
      itemBuilder: _buildAdminConnectionCard,
      emptyText: _tx('admin.connections_empty', 'Sin conexiones'),
      toolbar: _toolbar(
        buttons: [
          AppIconButton.outlined(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: _tx('admin.refresh', 'Actualizar'),
          ),
          FilterButton(
            activeCount: _connOwner.isNotEmpty ? 1 : 0,
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: () => _openOwnerFilterDialog(
              owners: _ownersOf(_connections),
              currentOwner: _connOwner,
              onChanged: (v) => _refresh(() => _connOwner = v),
            ),
          ),
        ],
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
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
                _badge(type, const Color(0xFF64748B)),
                if (tokens > 0)
                  _badge(_fmtTokens(tokens), const Color(0xFF0891B2)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
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
