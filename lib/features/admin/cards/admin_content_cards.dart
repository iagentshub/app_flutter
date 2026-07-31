part of '../pages/admin_page.dart';

extension _AdminContentCards on _AdminPageState {
  Widget _buildKnowledgeTab() {
    return _buildFilterableList(
      items: _filteredKnowledge,
      itemBuilder: _buildAdminKnowledgeCard,
      emptyText: _tx('admin.knowledge_empty', 'Sin elementos de Knowledge'),
      toolbar: _toolbar(
        search: TextField(
          controller: _knowledgeSearchController,
          decoration: InputDecoration(
            labelText: _tx(
              'admin.knowledge_search_hint',
              'Buscar por título o propietario',
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
          FilterButton(
            activeCount:
                (_knowledgeType.isNotEmpty ? 1 : 0) +
                (_knowledgeOwner.isNotEmpty ? 1 : 0),
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: _openKnowledgeFiltersDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildAdminKnowledgeCard(Map<String, dynamic> item) {
    final title = (item['title'] ?? item['id'] ?? '').toString();
    final type = (item['type'] ?? '').toString();
    final owner = _ownerOf(item);
    final chars = _asInt(item['char_count']);
    final date = _fmtDate(item['created_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
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
                _badge(
                  type == 'url'
                      ? 'URL'
                      : _tx('admin.type_document', 'Documento'),
                  type == 'url'
                      ? const Color(0xFF059669)
                      : const Color(0xFF64748B),
                ),
                _badge(
                  '${_tx('admin.table_chars', 'Caracteres')}: $chars',
                  const Color(0xFF0891B2),
                ),
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
                  onPressed: () => _changeOwner(item, 'knowledge'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteKnowledge(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Orquestaciones ──────────────────────────────────────────────

  Widget _buildWorkflowsTab() {
    return _buildFilterableList(
      items: _filteredWorkflows,
      itemBuilder: _buildAdminWorkflowCard,
      emptyText: _tx('admin.workflows_empty', 'Sin orquestaciones'),
      toolbar: _toolbar(
        search: TextField(
          controller: _workflowSearchController,
          decoration: InputDecoration(
            labelText: _tx(
              'admin.workflows_search_hint',
              'Buscar orquestación',
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
          FilterButton(
            activeCount: _workflowOwner.isNotEmpty ? 1 : 0,
            tooltip: _tx('common.filters', 'Filtros'),
            onPressed: () => _openOwnerFilterDialog(
              owners: _ownersOf(_workflows),
              currentOwner: _workflowOwner,
              onChanged: (v) => _refresh(() => _workflowOwner = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminWorkflowCard(Map<String, dynamic> item) {
    final name = (item['name'] ?? item['id'] ?? '').toString();
    final owner = _ownerOf(item);
    final steps = _asInt(item['steps']);
    final date = _fmtDate(item['updated_at']);

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
            _badge(
              '${_tx('admin.table_steps', 'Pasos')}: $steps',
              const Color(0xFF64748B),
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
                  onPressed: () => _changeOwner(item, 'workflow'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteWorkflow(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab: Configuración ───────────────────────────────────────────────

  Widget _buildConfigTab() {
    final token = _token;
    if (token == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: _AdminConfigTab(
          key: ValueKey(_platformSettings.hashCode),
          repository: _repository,
          token: token,
          initialSettings: _platformSettings ?? const {},
          tx: _tx,
          onSaved: (settings) => _refresh(() => _platformSettings = settings),
        ),
      ),
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────
