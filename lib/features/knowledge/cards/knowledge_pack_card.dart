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
              _tx('knowledge.pack_file_count')
                  .replaceAll('{{count}}', '${pack.fileCount}'),
            ),
            const SizedBox(height: 4),
            Text(switch (pack.sourceMode) {
              'reference' => _tx('knowledge.pack_source_reference_badge'),
              _ => _tx('knowledge.pack_source_upload_badge'),
            }, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: pack.displayLabels,
              labelText: (label) => trOr('labels.$label', label),
              leading: [
                OriginBadge(
                  propertyType: pack.propertyType,
                  ownerLabel: _tx('common.owner'),
                  linkedLabel: _tx('common.linked'),
                  forkLabel: _tx('common.fork'),
                ),
                if (!pack.isActive)
                  InactiveBadge(label: _tx('common.inactive')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                _buildKnowledgePackGraphButton(pack),
                if (!pack.readOnly)
                  OverflowMenuButton(
                    tooltip: _tx('common.more_actions'),
                    actions: [
                      if (pack.canSynchronize)
                        OverflowMenuAction(
                          icon: Icons.sync_outlined,
                          label: _tx('knowledge.pack_sync_action'),
                          onSelected: () => _synchronizePack(pack),
                        ),
                      OverflowMenuAction(
                        icon: Icons.edit_outlined,
                        label: _tx('common.edit'),
                        onSelected: () => _editPack(pack),
                      ),
                      OverflowMenuAction(
                        icon: Icons.group_add_outlined,
                        label: _tx('common.share_group'),
                        onSelected: () => _sharePack(pack),
                      ),
                      OverflowMenuAction(
                        icon: pack.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        label: _tx(
                          pack.isActive
                              ? 'common.deactivate'
                              : 'common.activate',
                        ),
                        onSelected: () => _togglePackActive(pack),
                      ),
                      OverflowMenuAction(
                        icon: Icons.delete_outline,
                        label: _tx('common.delete'),
                        danger: true,
                        separatedBefore: true,
                        onSelected: () => _deletePack(pack),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    return pack.isActive ? card : dimmedWhenInactive(context, card);
  }
}
