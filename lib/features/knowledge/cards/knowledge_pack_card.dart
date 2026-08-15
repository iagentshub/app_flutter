part of '../pages/knowledge_page.dart';

extension _KnowledgePackCard on _KnowledgePageState {
  Widget _buildPackCard(KnowledgePack pack) {
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pack.name,
                    style: const TextStyle(
                      fontSize: FncFonts.size16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (pack.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                pack.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _tx(
                'knowledge.pack_file_count',
                '{{count}} archivos',
              ).replaceAll('{{count}}', '${pack.fileCount}'),
            ),
            const SizedBox(height: 4),
            Text(switch (pack.sourceMode) {
              'reference' => _tx(
                'knowledge.pack_source_reference_badge',
                'Sólo referencias',
              ),
              _ => _tx(
                'knowledge.pack_source_upload_badge',
                'Contenido subido · sincronizable',
              ),
            }, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: pack.displayLabels,
              labelText: (label) => _tx('labels.$label', label),
              leading: [
                OriginBadge(
                  propertyType: pack.propertyType,
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
                _buildKnowledgePackGraphButton(pack),
                if (!pack.readOnly && pack.canSynchronize)
                  ActionIconButton(
                    icon: Icons.sync_outlined,
                    tooltip: _tx(
                      'knowledge.pack_sync_action',
                      'Volver a sincronizar directorio',
                    ),
                    onPressed: () => _synchronizePack(pack),
                  ),
                if (!pack.readOnly)
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: _tx('common.edit', 'Editar'),
                    onPressed: () => _editPack(pack),
                  ),
                if (!pack.readOnly)
                  ActionIconButton(
                    icon: Icons.group_add_outlined,
                    tooltip: _tx('common.share_group', 'Compartir con grupo'),
                    onPressed: () => _sharePack(pack),
                  ),
                if (!pack.readOnly)
                  ActionIconButton(
                    icon: Icons.delete_outline,
                    tooltip: _tx('common.delete', 'Eliminar'),
                    danger: true,
                    onPressed: () => _deletePack(pack),
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
