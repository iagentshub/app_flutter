part of '../pages/explore_page.dart';

extension _ExploreOfficialPackCard on _ExplorePageState {
  Widget _buildOfficialPackCard(ExploreOfficialPack pack) {
    final busy = _controller.isPackBusy(pack);
    final colorScheme = Theme.of(context).colorScheme;
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
              pack.name,
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  pack.provider == 'gitlab'
                      ? Icons.account_tree_outlined
                      : Icons.source_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    pack.repositoryOwner.isEmpty
                        ? pack.repositoryUrl
                        : pack.repositoryOwner,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${pack.linkedCount}/${pack.totalCount}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            if (pack.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                pack.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            LabelChipsRow(
              labels: const ['official'],
              labelText: (label) => _tx('labels.$label', label),
              leading: [
                ResourceTypeBadge(
                  type: 'official_pack',
                  label: _tx('explore.pack_badge', 'Pack'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final entry in pack.counts.entries.where(
                  (entry) => entry.value > 0,
                ))
                  _miniChip('${_typeChipLabel(entry.key)} ${entry.value}'),
              ],
            ),
            if (pack.matchingCount != pack.totalCount) ...[
              const SizedBox(height: 6),
              Text(
                _tx(
                      'explore.pack_matches',
                      '{{matching}} coincidencias · {{total}} recursos',
                    )
                    .replaceAll('{{matching}}', '${pack.matchingCount}')
                    .replaceAll('{{total}}', '${pack.totalCount}'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: _tx('explore.pack_open', 'Ver contenido'),
                  onPressed: busy ? null : () => _openOfficialPack(pack),
                ),
                ActionIconButton(
                  icon: pack.fullyLinked ? Icons.link : Icons.link_outlined,
                  tooltip: pack.fullyLinked
                      ? _tx('explore.pack_complete', 'Pack completo')
                      : pack.linkState == 'partial'
                      ? _tx('explore.pack_complete_action', 'Completar pack')
                      : _tx('explore.pack_link_all', 'Vincular pack'),
                  onPressed: busy || pack.fullyLinked || pack.ownedByRequester
                      ? null
                      : () => _confirmLinkOfficialPack(pack),
                ),
                const Spacer(),
                if (busy)
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOfficialPack(ExploreOfficialPack pack) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OfficialPackPage(
          pack: pack,
          repository: ExploreRepository(apiClient: _services.apiClient),
          token: token,
          tx: _tx,
        ),
      ),
    );
    if (changed == true) await _controller.load();
  }

  Future<void> _confirmLinkOfficialPack(ExploreOfficialPack pack) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('explore.pack_link_all', 'Vincular pack')),
        content: Text(
          _tx(
            'explore.pack_link_confirm',
            'Se vincularán los {{count}} recursos públicos del pack y sus dependencias.',
          ).replaceAll('{{count}}', '${pack.totalCount}'),
        ),
        actions: [
          SecondaryButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_tx('common.confirm', 'Confirmar')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAction(_controller.linkOfficialPack(pack));
    }
  }
}
