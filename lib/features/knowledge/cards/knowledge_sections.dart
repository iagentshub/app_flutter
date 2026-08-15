part of '../pages/knowledge_page.dart';

extension _KnowledgeSections on _KnowledgePageState {
  Widget _buildKnowledgeErrorState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Error cargando Knowledge',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_error!),
                const SizedBox(height: 12),
                PrimaryButton.icon(
                  onPressed: _load,
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

  Widget _buildDocumentsSection() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildKnowledgeErrorState();

    final allKnowledgeItems = [..._urlItems, ..._documentItems];
    final items = _knowledgePacksMode
        ? allKnowledgeItems.where((item) => item.packId == null).toList()
        : allKnowledgeItems;
    final collection = _knowledgePacksMode
        ? <Object>[..._packs, ...items]
        : <Object>[...items];
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
            emptyText: _tx(
              'knowledge.documents_empty',
              'No hay documentos todavía.',
            ),
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
                                      _tx(
                                        'knowledge.add_text_title',
                                        'Añadir texto',
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'document',
                                    child: Text(
                                      _tx(
                                        'knowledge.upload_document',
                                        'Subir documento',
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'image',
                                    child: Text(
                                      _tx(
                                        'knowledge.upload_image',
                                        'Subir imagen',
                                      ),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'url',
                                    child: Text(
                                      _tx('knowledge.import_url', 'Añadir URL'),
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'directory',
                                    child: Text(
                                      _tx(
                                        'knowledge.include_directory',
                                        'Incluir directorio de conocimiento',
                                      ),
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
                      tooltip: _tx(
                        'knowledge.add_content',
                        'Añadir conocimiento',
                      ),
                    ),
                    AppIconButton.outlined(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualizar',
                    ),
                    FilterButton(
                      activeCount: _knowledgeFilterCount,
                      tooltip: _tx('common.filters', 'Filtros'),
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
                          _tx(
                            'knowledge.drop_directory_here',
                            'Suelta el directorio para crear un pack de conocimiento',
                          ),
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
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (hasMore && notification.metrics.extentAfter < 500) {
            onLoadMore?.call();
          }
          return false;
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              sliver: SliverToBoxAdapter(child: toolbar),
            ),
            if (items.isEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(emptyText),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: ResponsiveSliverMasonryGrid(
                  itemCount: items.length,
                  itemBuilder: (context, index) => itemBuilder(items[index]),
                ),
              ),
            if (loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    if (_skillsLoading) return const Center(child: CircularProgressIndicator());

    if (_skillsError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Error cargando Skills',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_skillsError!),
                  const SizedBox(height: 12),
                  PrimaryButton.icon(
                    onPressed: _loadSkills,
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

    final filteredSkills = _filteredSkills;
    return _buildLazySection<SkillItem>(
      onRefresh: _loadSkills,
      items: filteredSkills,
      itemBuilder: _buildSkillCard,
      emptyText: 'No hay skills todavía.',
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
                tooltip: _tx('common.filters', 'Filtros'),
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
                if (!item.isActive) ...[
                  const SizedBox(width: 8),
                  InactiveBadge(label: _tx('common.inactive', 'Inactivo')),
                ],
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
              labelText: (label) => _tx('labels.$label', label),
              leading: [
                OriginBadge(
                  propertyType: item.propertyType,
                  ownerLabel: _tx('common.owner', 'Propietario'),
                  linkedLabel: _tx('common.linked', 'Enlace'),
                  forkLabel: _tx('common.fork', 'Fork'),
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
                    tooltip: _tx('common.share_group', 'Compartir con grupo'),
                    onPressed: () => _shareSkill(item),
                  ),
                ActionIconButton(
                  icon: Icons.history,
                  tooltip: _tx(
                    'history.dialog_title',
                    'Historial de versiones',
                  ),
                  onPressed: () => _showSkillHistory(item),
                ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: _tx('common.edit', 'Editar'),
                    onPressed: () => _openEditSkillDialog(item),
                  ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: item.isActive
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                    tooltip: item.isActive
                        ? _tx('common.deactivate', 'Desactivar')
                        : _tx('common.activate', 'Activar'),
                    onPressed: () => _toggleSkillActive(item),
                  ),
                if (!item.readOnly)
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

    if (item.isActive) return card;
    return dimmedWhenInactive(context, card);
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
              labelText: (label) => _tx('labels.$label', label),
              leading: [
                OriginBadge(
                  propertyType: item.propertyType,
                  ownerLabel: _tx('common.owner', 'Propietario'),
                  linkedLabel: _tx('common.linked', 'Enlace'),
                  forkLabel: _tx('common.fork', 'Fork'),
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
                    tooltip: _tx('common.edit', 'Editar'),
                    onPressed: () => _editItem(item),
                  ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.group_add_outlined,
                    tooltip: _tx('common.share_group', 'Compartir con grupo'),
                    onPressed: () => _shareItem(item),
                  ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: Icons.delete_outline,
                    tooltip: _tx('common.delete', 'Eliminar'),
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
