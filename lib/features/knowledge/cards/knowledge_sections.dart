part of '../pages/knowledge_page.dart';

extension _KnowledgeSections on _KnowledgePageState {
  Widget _buildKnowledgeErrorState() {
    return AsyncStatePanel.error(
      title: _tx('knowledge.documents_error_title'),
      message: _error!,
      retryLabel: _tx('common.retry'),
      onRetry: _load,
    );
  }

  Widget _buildDocumentsSection() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildKnowledgeErrorState();

    final collection = _knowledgeCollection;
    return DropTarget(
      enable: !_uploading,
      onDragEntered: (_) => refresh(() => _draggingDirectory = true),
      onDragExited: (_) => refresh(() => _draggingDirectory = false),
      onDragDone: _handleDirectoryDrop,
      child: Stack(
        children: [
          _buildLazySection<Object>(
            onRefresh: _load,
            onLoadMore: _loadMoreKnowledge,
            hasMore: _hasMoreKnowledge,
            loadingMore: _loadingMoreKnowledge,
            items: collection,
            itemBuilder: (entry) => entry is KnowledgePack
                ? _buildPackCard(entry)
                : _buildItemCard(entry as KnowledgeItem),
            emptyText: _tx('knowledge.documents_empty'),
            toolbar: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AppIconButton.filled(
                      onPressed: _uploading
                          ? null
                          : () async {
                              final box =
                                  context.findRenderObject() as RenderBox?;
                              final selected = await showMenu<String>(
                                context: context,
                                position: box == null
                                    ? const RelativeRect.fromLTRB(16, 80, 16, 0)
                                    : const RelativeRect.fromLTRB(
                                        16,
                                        80,
                                        16,
                                        0,
                                      ),
                                items: [
                                  PopupMenuItem(
                                    value: 'text',
                                    child: Text(
                                      _tx('knowledge.add_text_title'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'document',
                                    child: Text(
                                      _tx('knowledge.upload_document'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'image',
                                    child: Text(_tx('knowledge.upload_image')),
                                  ),
                                  PopupMenuItem(
                                    value: 'url',
                                    child: Text(_tx('knowledge.import_url')),
                                  ),
                                  PopupMenuItem(
                                    value: 'directory',
                                    child: Text(
                                      _tx('knowledge.include_directory'),
                                    ),
                                  ),
                                ],
                              );
                              if (selected == 'text') {
                                await _openAddTextDialog();
                              }
                              if (selected == 'document') {
                                await _uploadDocument();
                              }
                              if (selected == 'image') {
                                await _uploadDocument(imageOnly: true);
                              }
                              if (selected == 'url') {
                                await _openAddUrlDialog();
                              }
                              if (selected == 'directory') {
                                await _pickKnowledgeDirectory();
                              }
                            },
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      tooltip: _tx('knowledge.add_content'),
                    ),
                    AppIconButton.outlined(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar',
                    ),
                    FilterButton(
                      activeCount: _knowledgeFilterCount,
                      tooltip: _tx('common.filters'),
                      onPressed: _openKnowledgeFiltersDialog,
                    ),
                    ..._groupsButtons(),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _hasMoreKnowledge
                      ? '${collection.length}+'
                      : '${collection.length}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          if (_draggingDirectory)
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  child: Center(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _tx('knowledge.drop_directory_here'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (_packOperationMessage != null)
            Positioned.fill(
              child: AbsorbPointer(
                child: ColoredBox(
                  color: Theme.of(
                    context,
                  ).colorScheme.scrim.withValues(alpha: 0.34),
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      label: _packOperationMessage,
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 20,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 320),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  _packOperationMessage!,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Las cuatro pestañas comparten forma; lo único propio de Knowledge es qué
  /// tarjeta se pinta y de dónde salen las páginas.
  Widget _buildLazySection<T>({
    required Widget toolbar,
    required List<T> items,
    required Widget Function(T) itemBuilder,
    required String emptyText,
    required Future<void> Function() onRefresh,
    Future<void> Function()? onLoadMore,
    bool hasMore = false,
    bool loadingMore = false,
  }) {
    return ResourceCollectionView(
      header: toolbar,
      onRefresh: onRefresh,
      onLoadMore: onLoadMore,
      hasMore: hasMore,
      loadingMore: loadingMore,
      itemCount: items.length,
      itemBuilder: (context, index) => itemBuilder(items[index]),
      empty: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(emptyText),
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    if (_skillsLoading) return const Center(child: CircularProgressIndicator());

    if (_skillsError != null) {
      // El título estaba escrito a mano en español, sin pasar por el
      // diccionario, en la única pestaña que no lo traducía.
      return AsyncStatePanel.error(
        title: _tx('knowledge.skills_error_title'),
        message: _skillsError!,
        retryLabel: _tx('common.retry'),
        onRetry: _loadSkills,
      );
    }

    final filteredSkills = _filteredSkills;
    return _buildLazySection<SkillItem>(
      onRefresh: _loadSkills,
      items: filteredSkills,
      itemBuilder: _buildSkillCard,
      emptyText: tr('knowledge.no_skills'),
      toolbar: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppIconButton.filled(
                onPressed: _openCreateSkillChoiceDialog,
                icon: const Icon(Icons.add),
                tooltip: 'Nueva skill',
              ),
              AppIconButton.outlined(
                onPressed: _loadSkills,
                icon: const Icon(Icons.refresh),
                tooltip: 'Actualizar',
              ),
              FilterButton(
                activeCount: _skillFilterCount,
                tooltip: _tx('common.filters'),
                onPressed: _openSkillFiltersDialog,
              ),
              ..._groupsButtons(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Skills: ${filteredSkills.length}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSkillCard(SkillItem item) {
    final metaParts = <String>[item.scope];
    if (item.category.isNotEmpty) metaParts.add(item.category);

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(skillCategoryIcon(item.category), size: 20),
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
                  resourceType: 'skill',
                ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.group_add_outlined,
                    tooltip: _tx('common.share_group'),
                    onPressed: () => _shareSkill(item),
                  ),
                ActionIconButton(
                  icon: Icons.history,
                  tooltip: _tx('history.dialog_title'),
                  onPressed: () => _showSkillHistory(item),
                ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: _tx('common.edit'),
                    onPressed: () => _openEditSkillDialog(item),
                  ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.delete_outline,
                    tooltip: _tx('common.delete'),
                    danger: true,
                    onPressed: () => _deleteSkill(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return card;
  }

  Widget _buildItemCard(KnowledgeItem item) {
    if (item.isImage) return _buildImageCard(item);
    final icon = switch (item.type) {
      'url' => Icons.public,
      'document' => Icons.description_outlined,
      _ => Icons.notes_outlined,
    };

    final metaParts = <String>[item.type, '${item.charCount} chars'];
    if (item.source.isNotEmpty) metaParts.add(item.source);

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.title,
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
            if (item.preview.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.preview.trim(),
                maxLines: 4,
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
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                _buildKnowledgeItemGraphButton(item),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: _tx('common.edit'),
                    onPressed: () => _editItem(item),
                  ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.group_add_outlined,
                    tooltip: _tx('common.share_group'),
                    onPressed: () => _shareItem(item),
                  ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.delete_outline,
                    tooltip: _tx('common.delete'),
                    danger: true,
                    onPressed: () => _deleteItem(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return card;
  }
}
