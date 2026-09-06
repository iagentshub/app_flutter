part of '../pages/knowledge_page.dart';

extension _KnowledgeImageCard on _KnowledgePageState {
  Widget _buildImageCard(KnowledgeItem item) {
    final parsedDate = DateTime.tryParse(item.createdAt)?.toLocal();
    final date = parsedDate == null
        ? '—'
        : MaterialLocalizations.of(context).formatShortDate(parsedDate);
    final size = item.sizeBytes > 0 ? formatFileSize(item.sizeBytes) : '—';
    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(kIsWeb ? 16 : 12),
        child: ResourceCardBody(
          children: [
            Row(
              children: [
                const Icon(Icons.image_outlined, size: 20),
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
            Text('$size · $date'),
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: item.displayLabels,
              labelText: (label) => trOr('labels.$label', label),
              leading: [
                if (!item.isActive)
                  InactiveBadge(label: _tx('common.inactive')),
              ],
            ),
            if (!item.readOnly) ...[
              const SizedBox(height: 10),
              ResourceTrailingActions(
                children: [
                  _buildKnowledgeItemGraphButton(item),
                  OverflowMenuButton(
                    tooltip: _tx('common.more_actions'),
                    actions: [
                      OverflowMenuAction(
                        icon: Icons.edit_outlined,
                        label: _tx('common.edit'),
                        onSelected: () => _editItem(item),
                      ),
                      OverflowMenuAction(
                        icon: Icons.group_add_outlined,
                        label: _tx('common.share_group'),
                        onSelected: () => _shareItem(item),
                      ),
                      OverflowMenuAction(
                        icon: item.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                        label: _tx(
                          item.isActive
                              ? 'common.deactivate'
                              : 'common.activate',
                        ),
                        onSelected: () => _toggleItemActive(item),
                      ),
                      OverflowMenuAction(
                        icon: Icons.delete_outline,
                        label: _tx('common.delete'),
                        danger: true,
                        separatedBefore: true,
                        onSelected: () => _deleteItem(item),
                      ),
                    ],
                  ),
                ],
              ),
            ] else if (kIsWeb)
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
    return item.isActive ? card : dimmedWhenInactive(context, card);
  }
}
