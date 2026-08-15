part of '../pages/knowledge_page.dart';

extension _KnowledgeImageCard on _KnowledgePageState {
  Widget _buildImageCard(KnowledgeItem item) {
    final parsedDate = DateTime.tryParse(item.createdAt)?.toLocal();
    final date = parsedDate == null
        ? '—'
        : MaterialLocalizations.of(context).formatShortDate(parsedDate);
    final size = item.sizeBytes > 0
        ? formatToolBinarySize(item.sizeBytes)
        : '—';
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
              labelText: (label) => _tx('labels.$label', label),
            ),
            if (!item.readOnly) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildKnowledgeItemGraphButton(item),
                  ActionIconButton(
                    icon: Icons.edit_outlined,
                    tooltip: _tx('common.edit', 'Editar'),
                    onPressed: () => _editItem(item),
                  ),
                  ActionIconButton(
                    icon: Icons.group_add_outlined,
                    tooltip: _tx('common.share_group', 'Compartir con grupo'),
                    onPressed: () => _shareItem(item),
                  ),
                  ActionIconButton(
                    icon: Icons.delete_outline,
                    tooltip: _tx('common.delete', 'Eliminar'),
                    danger: true,
                    onPressed: () => _deleteItem(item),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
