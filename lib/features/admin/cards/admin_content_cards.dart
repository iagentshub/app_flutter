part of '../pages/admin_page.dart';

extension _AdminContentCards on _AdminPageState {
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
                _resourceTypeBadge(AdminResourceType.knowledge),
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
                _resourceGraphAction(AdminResourceType.knowledge, item),
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _resourceTypeBadge(AdminResourceType.workflow),
                _badge(
                  '${_tx('admin.table_steps', 'Pasos')}: $steps',
                  const Color(0xFF64748B),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                _resourceGraphAction(AdminResourceType.workflow, item),
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

  Widget _buildAdminSkillCard(Map<String, dynamic> item) {
    final name = (item['name'] ?? item['id'] ?? '').toString();
    final category = (item['category'] ?? '').toString();
    final owner = _ownerOf(item);
    final date = _fmtDate(item['created_at']);

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
                _resourceTypeBadge(AdminResourceType.skill),
                if (category.isNotEmpty)
                  _badge(category, const Color(0xFF64748B)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                _resourceGraphAction(AdminResourceType.skill, item),
                ActionIconButton(
                  icon: Icons.swap_horiz,
                  tooltip: _tx(
                    'admin.action_change_owner',
                    'Cambiar propietario',
                  ),
                  onPressed: () => _changeOwner(item, 'skill'),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteSkill(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Sin botón de "cambiar propietario": a diferencia del resto de recursos,
  /// el nombre de un fichero de memoria lo elige el usuario y solo es único
  /// por dueño — moverlo de propietario podría chocar con un fichero ya
  /// existente con el mismo nombre bajo el nuevo dueño.
  Widget _buildAdminMemoryCard(Map<String, dynamic> item) {
    final filename = (item['filename'] ?? item['id'] ?? '').toString();
    final owner = _ownerOf(item);
    final size = _asInt(item['size']);
    final date = _fmtDate(item['updated_at']);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              filename,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
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
                _resourceTypeBadge(AdminResourceType.memory),
                _badge(
                  '${_tx('admin.table_chars', 'Caracteres')}: $size',
                  const Color(0xFF0891B2),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                _resourceGraphAction(AdminResourceType.memory, item),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteMemory(item),
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
    return _AdminConfigTab(
      key: ValueKey(_platformSettings.hashCode),
      repository: _repository,
      token: token,
      initialSettings: _platformSettings ?? const {},
      tx: _tx,
      onSaved: (settings) => _refresh(() => _platformSettings = settings),
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────
