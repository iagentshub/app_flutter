part of '../pages/explore_page.dart';

extension _ExploreResourceCard on _ExplorePageState {
  static const _linkableTypes = {'agent', 'skill', 'knowledge', 'workflow'};

  Widget _buildItemCard(ExploreItem item) {
    final key = _itemKey(item);
    final busy = _busyKeys.contains(key);
    final myUsername = widget.sessionController.user?.username ?? '';
    final isOwn = myUsername.isNotEmpty && item.ownerUsername == myUsername;
    final isLinkable = !isOwn && _linkableTypes.contains(item.resourceType);
    final linked = _linkedKeys.contains(key);
    final starred = _starredKeys.contains(key);

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.ownerUsername,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.star, size: 14, color: Colors.amber.shade600),
                const SizedBox(width: 4),
                Text(
                  '${item.stars}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: item.labels,
              leading: [
                ResourceTypeBadge(
                  type: item.resourceType,
                  label: _typeChipLabel(item.resourceType),
                ),
                _chip(_categoryChipLabel(item.category)),
              ],
            ),
            if (item.tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: item.tags
                    .take(4)
                    .map((tag) => _miniChip('#$tag'))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: _tx('explore.preview', 'Vista previa'),
                  onPressed: busy ? null : () => _preview(item),
                ),
                if (isLinkable)
                  ActionIconButton(
                    icon: linked ? Icons.link : Icons.link_outlined,
                    tooltip: linked
                        ? _tx('explore.linked_tooltip', 'Ya enlazado')
                        : _tx('explore.link', 'Enlazar'),
                    onPressed: (busy || linked) ? null : () => _link(item),
                  ),
                const Spacer(),
                ActionIconButton(
                  icon: starred ? Icons.star : Icons.star_outline,
                  tooltip: starred
                      ? _tx('explore.unstar', 'Quitar de favoritos')
                      : _tx('explore.star', 'Añadir a favoritos'),
                  onPressed: busy ? null : () => _toggleStar(item),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11)),
    );
  }
}
