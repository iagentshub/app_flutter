part of '../pages/knowledge_page.dart';

/// Pestaña "Prompts" de Knowledge: calco de `_KnowledgeSections` para skills,
/// separado en su propio fichero para no hacer crecer sin límite
/// `knowledge_sections.dart` (ver `feature_architecture_test.dart`).
extension _PromptSections on _KnowledgePageState {
  Widget _buildPromptsErrorState() {
    return AsyncStatePanel.error(
      title: _tx('knowledge.prompts_error_title'),
      message: _promptsError!,
      retryLabel: _tx('common.retry'),
      onRetry: _loadPrompts,
    );
  }

  Widget _buildPromptsSection() {
    if (_promptsLoading) {
      return const Center(child: IAgentsLoadingMark());
    }
    if (_promptsError != null) return _buildPromptsErrorState();

    final filteredPrompts = _filteredPrompts;
    return _buildLazySection<PromptItem>(
      onRefresh: _loadPrompts,
      items: filteredPrompts,
      itemBuilder: _buildPromptCard,
      emptyText: _tx('knowledge.no_prompts'),
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
                tooltip: _tx('knowledge.new_prompt'),
              ),
              AppIconButton.outlined(
                onPressed: _loadPrompts,
                icon: const Icon(Icons.refresh),
                tooltip: _tx('common.update'),
              ),
              FilterButton(
                activeCount: _promptFilterCount,
                tooltip: _tx('common.filters'),
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
              labels: item.displayLabels,
              labelText: (label) => trOr('labels.$label', label),
              leading: [
                OriginBadge(
                  propertyType: item.propertyType,
                  ownerLabel: _tx('common.owner'),
                  linkedLabel: _tx('common.linked'),
                  forkLabel: _tx('common.fork'),
                ),
                _aliasChip('@${item.alias}'),
                if (!item.isActive)
                  InactiveBadge(label: _tx('common.inactive')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                _buildResourceGraphButton(
                  resourceId: item.id,
                  resourceName: item.name,
                  resourceDescription: item.description,
                  resourceType: 'prompt',
                ),
                OverflowMenuButton(
                  tooltip: _tx('common.more_actions'),
                  actions: [
                    if (!item.readOnly)
                      OverflowMenuAction(
                        icon: Icons.group_add_outlined,
                        label: _tx('common.share_group'),
                        onSelected: () => _sharePrompt(item),
                      ),
                    OverflowMenuAction(
                      icon: Icons.history,
                      label: _tx('history.dialog_title'),
                      onSelected: () => _showPromptHistory(item),
                    ),
                    if (!item.readOnly)
                      OverflowMenuAction(
                        icon: Icons.edit_outlined,
                        label: _tx('common.edit'),
                        onSelected: () => _openEditPromptDialog(item),
                      ),
                    if (!item.readOnly)
                      OverflowMenuAction(
                        icon: item.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        label: _tx(
                          item.isActive
                              ? 'common.deactivate'
                              : 'common.activate',
                        ),
                        onSelected: () => _togglePromptActive(item),
                      ),
                    if (!item.readOnly)
                      OverflowMenuAction(
                        icon: Icons.delete_outline,
                        label: _tx('common.delete'),
                        danger: true,
                        separatedBefore: true,
                        onSelected: () => _deletePrompt(item),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return item.isActive ? card : dimmedWhenInactive(context, card);
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
