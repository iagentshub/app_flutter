part of '../pages/knowledge_page.dart';

/// Pestaña "Herramientas" de Knowledge: calco de `_KnowledgeSections` para
/// skills, separado en su propio fichero para no hacer crecer sin límite
/// `knowledge_sections.dart` (ver `feature_architecture_test.dart`).
extension _ToolSections on _KnowledgePageState {
  Widget _buildToolsErrorState() {
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
                  _tx(
                    'knowledge.tools_error_title',
                    'Error cargando Herramientas',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(_toolsError!),
                const SizedBox(height: 12),
                PrimaryButton.icon(
                  onPressed: _loadTools,
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

  Widget _buildToolsSection() {
    if (_toolsLoading) return const Center(child: CircularProgressIndicator());
    if (_toolsError != null) return _buildToolsErrorState();

    final filteredTools = _filteredTools;
    return _buildLazySection<ToolItem>(
      onRefresh: _loadTools,
      items: filteredTools,
      itemBuilder: _buildToolCard,
      emptyText: _tx('knowledge.no_tools', 'No hay herramientas todavía.'),
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
                tooltip: _tx('knowledge.new_tool', 'Nueva herramienta'),
              ),
              AppIconButton.outlined(
                onPressed: _loadTools,
                icon: const Icon(Icons.refresh),
                tooltip: _tx('common.update', 'Actualizar'),
              ),
              FilterButton(
                activeCount: _toolFilterCount,
                tooltip: _tx('common.filters', 'Filtros'),
                onPressed: _openToolFiltersDialog,
              ),
              ..._groupsButtons(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_tx('knowledge.tab_tools', 'Herramientas')}: ${filteredTools.length}',
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
            _tx('knowledge.execution_coming_soon', 'Ejecución próximamente'),
            style: const TextStyle(fontSize: FncFonts.size10),
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(ToolItem item) {
    final metaParts = <String>[
      item.scope,
      toolLanguageLabel(_tx, item.language),
    ];

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(toolLanguageIcon(item.language), size: 20),
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
            if (item.language == 'cpp') ...[
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
                          ? '${item.binaryFilename} · ${formatToolBinarySize(item.binarySize ?? 0)}'
                          : _tx('knowledge.no_binary', 'Sin binario todavía'),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (item.hasBinary)
                    ActionIconButton(
                      icon: Icons.download_outlined,
                      tooltip: _tx(
                        'knowledge.download_binary',
                        'Descargar binario',
                      ),
                      onPressed: () => _downloadToolBinary(item),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            LabelChipsRow(
              labels: item.labels,
              leading: [
                OriginBadge(
                  shared: item.shared,
                  ownerLabel: _tx('common.owner', 'Propietario'),
                  linkedLabel: _tx('common.linked', 'Enlazado'),
                ),
                _executionComingSoonBadge(),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.group_add_outlined,
                  tooltip: _tx('common.share_group', 'Compartir con grupo'),
                  onPressed: () => _shareTool(item),
                ),
                ActionIconButton(
                  icon: Icons.history,
                  tooltip: _tx(
                    'history.dialog_title',
                    'Historial de versiones',
                  ),
                  onPressed: () => _showToolHistory(item),
                ),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _openEditToolDialog(item),
                ),
                if (!item.readOnly)
                  ActionIconButton(
                    icon: item.isActive
                        ? Icons.toggle_on_outlined
                        : Icons.toggle_off_outlined,
                    tooltip: item.isActive
                        ? _tx('common.deactivate', 'Desactivar')
                        : _tx('common.activate', 'Activar'),
                    onPressed: () => _toggleToolActive(item),
                  ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteTool(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (item.isActive) return card;
    return Opacity(opacity: 0.6, child: card);
  }
}
