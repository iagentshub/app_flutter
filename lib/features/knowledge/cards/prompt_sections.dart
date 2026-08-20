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
      return const Center(child: CircularProgressIndicator());
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
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.group_add_outlined,
                    tooltip: _tx('common.share_group'),
                    onPressed: () => _sharePrompt(item),
                  ),
                ActionIconButton(
                  icon: Icons.history,
                  tooltip: _tx('history.dialog_title'),
                  onPressed: () => _showPromptHistory(item),
                ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: _tx('common.edit'),
                    onPressed: () => _openEditPromptDialog(item),
                  ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.delete_outline,
                    tooltip: _tx('common.delete'),
                    danger: true,
                    onPressed: () => _deletePrompt(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return card;
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
