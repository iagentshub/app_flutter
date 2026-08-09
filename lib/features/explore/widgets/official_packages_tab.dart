part of '../pages/explore_page.dart';

extension _OfficialPackagesTab on _ExplorePageState {
  Widget _buildOfficialPackagesTab() {
    if (_officialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _officialError;
    if (error != null) {
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
                      'official.load_error',
                      'No se pudo cargar la biblioteca oficial',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(error),
                  const SizedBox(height: 12),
                  PrimaryButton.icon(
                    onPressed: _loadOfficialPackages,
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
    return RefreshIndicator(
      onRefresh: _loadOfficialPackages,
      child: _officialPackages.isEmpty
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _tx(
                        'official.empty',
                        'Todavía no hay paquetes oficiales publicados.',
                      ),
                    ),
                  ),
                ),
              ],
            )
          : CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_officialCopies.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _tx(
                                  'official.my_copies',
                                  'Mis copias editables',
                                ),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ..._officialCopies.map(
                                (copy) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.fork_right),
                                  title: Text(copy.name),
                                  subtitle: Text(
                                    '${_tx('official.based_on', 'Basado en')} ${copy.packageName} ${copy.sourceVersion}',
                                  ),
                                  trailing: _miniChip(copy.status),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: ResponsiveSliverMasonryGrid(
                    itemCount: _officialPackages.length,
                    itemBuilder: (context, index) =>
                        _buildOfficialPackageCard(_officialPackages[index]),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOfficialPackageCard(OfficialPackageItem item) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified, color: FncColors.success, size: 20),
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
                _chip(_tx('official.badge', 'Oficial')),
              ],
            ),
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _miniChip(item.publishedVersion),
                if (item.license.isNotEmpty) _miniChip(item.license),
                _miniChip('Codex'),
                _miniChip('Claude'),
                _miniChip('Cursor'),
              ],
            ),
            const SizedBox(height: 12),
            PrimaryButton.icon(
              onPressed: () => _openOfficialPackage(item),
              icon: const Icon(Icons.tune),
              label: Text(
                _tx('official.choose_components', 'Elegir componentes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openOfficialPackage(OfficialPackageItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final detail = await _officialRepository.get(token, item.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _OfficialPackageDialog(
          detail: detail,
          tx: _tx,
          onCopy: (ids) => _copyOfficialPackage(detail, ids),
          onExport: (target, ids) =>
              _exportOfficialPackage(detail, target, ids),
        ),
      );
    } catch (error) {
      showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _copyOfficialPackage(
    OfficialPackageDetail detail,
    Set<String> ids,
  ) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final result = await _officialRepository.copy(token, detail.id, ids);
    if (!mounted) return;
    final count = (result['copies'] as List?)?.length ?? 0;
    await _loadOfficialPackages();
    if (!mounted) return;
    showMessage(
      _tx(
        'official.copied',
        '{count} componentes copiados',
      ).replaceAll('{count}', '$count'),
    );
  }

  Future<void> _exportOfficialPackage(
    OfficialPackageDetail detail,
    String target,
    Set<String> ids,
  ) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final preview = await _officialRepository.previewExport(
      token,
      detail.id,
      target,
      ids,
    );
    if (!mounted) return;
    final files = (preview['files'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item['path']?.toString() ?? '')
        .where((path) => path.isNotEmpty)
        .toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _tx('official.export_preview', 'Vista previa de exportación'),
        ),
        content: SizedBox(
          width: 620,
          child: SingleChildScrollView(child: SelectableText(files.join('\n'))),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_tx('official.download_zip', 'Descargar ZIP')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result = await _officialRepository.export(
      token,
      detail.id,
      target,
      ids,
    );
    await FilePicker.saveFile(
      dialogTitle: _tx('official.download_zip', 'Descargar ZIP'),
      fileName: result.filename ?? '${detail.id}-$target.zip',
      bytes: result.bytes,
    );
  }
}

class _OfficialPackageDialog extends StatefulWidget {
  const _OfficialPackageDialog({
    required this.detail,
    required this.tx,
    required this.onCopy,
    required this.onExport,
  });

  final OfficialPackageDetail detail;
  final String Function(String, String) tx;
  final Future<void> Function(Set<String>) onCopy;
  final Future<void> Function(String, Set<String>) onExport;

  @override
  State<_OfficialPackageDialog> createState() => _OfficialPackageDialogState();
}

class _OfficialPackageDialogState extends State<_OfficialPackageDialog> {
  late final Set<String> selected = widget.detail.components
      .map((e) => e.id)
      .toSet();
  String target = 'codex';
  bool busy = false;

  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.detail.name} · ${widget.detail.publishedVersion}'),
      content: SizedBox(
        width: dialogContentWidth(context, 760),
        height: dialogContentHeight(context, 480),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: target,
                    decoration: InputDecoration(
                      labelText: widget.tx('official.target', 'Destino'),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'codex', child: Text('Codex')),
                      DropdownMenuItem(
                        value: 'claude',
                        child: Text('Claude Code'),
                      ),
                      DropdownMenuItem(value: 'cursor', child: Text('Cursor')),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => setState(() => target = value ?? target),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${selected.length}/${widget.detail.components.length}'),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  for (final component in widget.detail.components)
                    CheckboxListTile(
                      value: selected.contains(component.id),
                      title: Text(component.name),
                      subtitle: Text(
                        '${component.type} · ${component.sourcePath}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: busy
                          ? null
                          : (value) => setState(() {
                              if (value == true) {
                                selected.add(component.id);
                              } else {
                                selected.remove(component.id);
                              }
                            }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(widget.tx('common.close', 'Cerrar')),
        ),
        SecondaryButton.icon(
          onPressed: busy || selected.isEmpty
              ? null
              : () => run(() => widget.onCopy(selected)),
          icon: const Icon(Icons.copy_outlined),
          label: Text(widget.tx('official.copy', 'Crear copia editable')),
        ),
        PrimaryButton.icon(
          onPressed: busy || selected.isEmpty
              ? null
              : () => run(() => widget.onExport(target, selected)),
          icon: const Icon(Icons.download_outlined),
          label: Text(widget.tx('official.export', 'Exportar')),
        ),
      ],
    );
  }
}
