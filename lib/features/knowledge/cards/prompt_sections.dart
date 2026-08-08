part of '../pages/knowledge_page.dart';

/// Pestaña "Prompts" de Knowledge: calco de `_KnowledgeSections` para skills,
/// separado en su propio fichero para no hacer crecer sin límite
/// `knowledge_sections.dart` (ver `feature_architecture_test.dart`).
extension _PromptSections on _KnowledgePageState {
  Widget _buildPromptsErrorState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tx('knowledge.prompts_error_title', 'Error cargando Prompts'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_promptsError!),
                const SizedBox(height: 12),
                PrimaryButton.icon(
                  onPressed: _loadPrompts,
                  icon: const Icon(Icons.refresh),
                  label: Text(_tx('common.retry', 'Reintentar')),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPromptsSection() {
    if (_promptsLoading) return const Center(child: CircularProgressIndicator());
    if (_promptsError != null) return _buildPromptsErrorState();

    final filteredPrompts = _filteredPrompts;
    return _buildLazySection<PromptItem>(
      onRefresh: _loadPrompts,
      items: filteredPrompts,
      itemBuilder: _buildPromptCard,
      emptyText: _tx('knowledge.no_prompts', 'No hay prompts todavía.'),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppIconButton.filled(
                onPressed: _openCreatePromptDialog,
                icon: const Icon(Icons.add),
                tooltip: _tx('knowledge.new_prompt', 'Nuevo prompt'),
              ),
              AppIconButton.outlined(
                onPressed: _loadPrompts,
                icon: const Icon(Icons.refresh),
                tooltip: _tx('common.update', 'Actualizar'),
              ),
              FilterButton(
                activeCount: _promptFilterCount,
                tooltip: _tx('common.filters', 'Filtros'),
                onPressed: _openPromptFiltersDialog,
              ),
              ..._groupsButtons(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Prompts: ${filteredPrompts.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildPromptCard(PromptItem item) {
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: FncFonts.size16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!item.isActive) ...[
                  const SizedBox(width: 8),
                  InactiveBadge(label: _tx('common.inactive', 'Inactivo')),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(item.scope),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: item.labels,
              leading: [
                OriginBadge(
                  shared: item.shared,
                  ownerLabel: _tx('common.owner', 'Propietario'),
                  linkedLabel: _tx('common.linked', 'Enlazado'),
                ),
                _aliasChip('@${item.alias}'),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: _tx('common.share_group', 'Compartir con grupo'),
                  onPressed: () => _sharePrompt(item),
                ),
                ActionIconButton(
                  icon: Icons.history,
                  tooltip: _tx(
                    'history.dialog_title',
                    'Historial de versiones',
                  ),
                  onPressed: () => _showPromptHistory(item),
                ),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditPromptDialog(item),
                ),
                // activate/deactivate no tiene rama is_guest en el backend:
                // sigue cerrado al invitado, así que se oculta aquí también.
                if (!item.readOnly &&
                    widget.sessionController.user?.role != 'guest')
                  ActionIconButton(
                    icon: item.isActive
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                    tooltip: item.isActive
                        ? _tx('common.deactivate', 'Desactivar')
                        : _tx('common.activate', 'Activar'),
                    onPressed: () => _togglePromptActive(item),
                  ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deletePrompt(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (item.isActive) return card;
    return dimmedWhenInactive(context, card);
  }

  /// Chip secundario con el alias `@invocable` del prompt, mismo estilo
  /// visual (píldora de color) que los demás badges de la fila de labels.
  Widget _aliasChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: labelColor('prompt'),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: FncColors.white,
          fontSize: FncFonts.size10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
