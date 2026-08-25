part of '../pages/knowledge_page.dart';

/// Pestaña "Herramientas" de Knowledge: calco de `_KnowledgeSections` para
/// skills, separado en su propio fichero para no hacer crecer sin límite
/// `knowledge_sections.dart` (ver `feature_architecture_test.dart`).
extension _ToolSections on _KnowledgePageState {
  Widget _buildToolsErrorState() {
    return AsyncStatePanel.error(
      title: _tx('knowledge.tools_error_title'),
      message: _toolsError!,
      retryLabel: _tx('common.retry'),
      onRetry: _loadTools,
    );
  }

  Widget _buildToolsSection() {
    if (_toolsLoading) return const Center(child: IAgentsLoadingMark());
    if (_toolsError != null) return _buildToolsErrorState();

    final filteredTools = _filteredTools;
    return _buildLazySection<ToolItem>(
      onRefresh: _loadTools,
      items: filteredTools,
      itemBuilder: _buildToolCard,
      emptyText: _tx('knowledge.no_tools'),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppIconButton.filled(
                onPressed: _openCreateToolDialog,
                icon: const Icon(Icons.add),
                tooltip: _tx('knowledge.new_tool'),
              ),
              AppIconButton.outlined(
                onPressed: _loadTools,
                icon: const Icon(Icons.refresh),
                tooltip: _tx('common.update'),
              ),
              FilterButton(
                activeCount: _toolFilterCount,
                tooltip: _tx('common.filters'),
                onPressed: _openToolFiltersDialog,
              ),
              ..._groupsButtons(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_tx('knowledge.tab_tools')}: ${filteredTools.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  /// Badge discreto que deja claro que la card no está rota sin botón de
  /// ejecutar: Fase 1 es solo catalogación + asignación, sin motor de
  /// ejecución (ver plan de la Fase 1).
  Widget _executionComingSoonBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: FncColors.slate.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule, size: 12),
          const SizedBox(width: 4),
          Text(
            _tx('knowledge.execution_coming_soon'),
            style: const TextStyle(fontSize: FncFonts.size10),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(ToolItem item) {
    final metaParts = <String>[item.scope, item.languageLabel(_tx)];

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(item.language.icon, size: 20),
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
            Text(metaParts.join(' · ')),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            if (item.language.requiresBinary) ...[
              Row(
                children: [
                  Icon(
                    item.hasBinary
                        ? Icons.insert_drive_file_outlined
                        : Icons.error_outline,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.hasBinary
                          ? '${item.binaryFilename} · ${formatFileSize(item.binarySize ?? 0)}'
                          : _tx('knowledge.no_binary'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.hasBinary)
                    ActionIconButton(
                      icon: Icons.download_outlined,
                      tooltip: _tx('knowledge.download_binary'),
                      onPressed: () => _downloadToolBinary(item),
                    ),
                ],
              ),
              if (item.binarySha256.isNotEmpty) ...[
                const SizedBox(height: 4),
                SelectableText(
                  '${_tx('knowledge.binary_sha256')}: ${item.binarySha256}',
                  style: const TextStyle(
                    fontFamily: FncFonts.monospace,
                    fontSize: FncFonts.size10,
                  ),
                ),
              ],
              if (item.binaryUploadedBy.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  '${_tx('knowledge.binary_uploaded_by')}: ${item.binaryUploadedBy}',
                  style: const TextStyle(fontSize: FncFonts.size10),
                ),
              ],
              const SizedBox(height: 8),
            ],
            LabelChipsRow(
              labels: item.displayLabels,
              leading: [
                OriginBadge(
                  propertyType: item.propertyType,
                  ownerLabel: _tx('common.owner'),
                  linkedLabel: _tx('common.linked'),
                  forkLabel: _tx('common.fork'),
                ),
                _executionComingSoonBadge(),
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
                  resourceType: 'tool',
                ),
                OverflowMenuButton(
                  tooltip: _tx('common.more_actions'),
                  actions: [
                    if (!item.readOnly)
                      OverflowMenuAction(
                        icon: Icons.group_add_outlined,
                        label: _tx('common.share_group'),
                        onSelected: () => _shareTool(item),
                      ),
                    OverflowMenuAction(
                      icon: Icons.history,
                      label: _tx('history.dialog_title'),
                      onSelected: () => _showToolHistory(item),
                    ),
                    if (!item.readOnly)
                      OverflowMenuAction(
                        icon: Icons.edit_outlined,
                        label: _tx('common.edit'),
                        onSelected: () => _openEditToolDialog(item),
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
                        onSelected: () => _toggleToolActive(item),
                      ),
                    if (!item.readOnly)
                      OverflowMenuAction(
                        icon: Icons.delete_outline,
                        label: _tx('common.delete'),
                        danger: true,
                        separatedBefore: true,
                        onSelected: () => _deleteTool(item),
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
}
