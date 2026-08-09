part of '../pages/explore_page.dart';

extension _OfficialResourceActions on _ExplorePageState {
  Future<void> _useOfficialResource(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty || item.officialPackageId.isEmpty) {
      return;
    }
    if (_officialBusyKeys.contains(item.resourceId)) return;
    _setOfficialBusy(item.resourceId, busy: true);
    try {
      final result = await _officialRepository.copy(
        token,
        item.officialPackageId,
        {item.officialComponentId},
      );
      if (!mounted) return;
      final count = (result['copies'] as List?)?.length ?? 0;
      showMessage(
        _tx(
          'official.copied',
          '{count} componentes copiados',
        ).replaceAll('{count}', '$count'),
      );
    } catch (error) {
      if (mounted) showMessage(error.toString(), isError: true);
    } finally {
      _setOfficialBusy(item.resourceId, busy: false);
    }
  }

  Future<void> _downloadOfficialResource(ExploreItem item) async {
    final target = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_tx('official.target', 'Destino')),
        children: [
          for (final option in const [
            ('codex', 'Codex'),
            ('claude', 'Claude Code'),
            ('cursor', 'Cursor'),
          ])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, option.$1),
              child: Text(option.$2),
            ),
        ],
      ),
    );
    if (target == null || !mounted) return;
    await _exportOfficialResource(item, target);
  }

  Future<void> _exportOfficialResource(ExploreItem item, String target) async {
    final token = _token;
    if (token == null || token.isEmpty || item.officialPackageId.isEmpty) {
      return;
    }
    if (_officialBusyKeys.contains(item.resourceId)) return;
    _setOfficialBusy(item.resourceId, busy: true);
    final ids = {item.officialComponentId};
    try {
      final preview = await _officialRepository.previewExport(
        token,
        item.officialPackageId,
        target,
        ids,
      );
      if (!mounted) return;
      final files = (preview['files'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => entry['path']?.toString() ?? '')
          .where((path) => path.isNotEmpty)
          .toList();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            _tx('official.export_preview', 'Vista previa de exportación'),
          ),
          content: SizedBox(
            width: dialogContentWidth(context, 620),
            child: SingleChildScrollView(
              child: SelectableText(files.join('\n')),
            ),
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
        item.officialPackageId,
        target,
        ids,
      );
      await FilePicker.saveFile(
        dialogTitle: _tx('official.download_zip', 'Descargar ZIP'),
        fileName: result.filename ?? '${item.officialComponentId}-$target.zip',
        bytes: result.bytes,
      );
    } catch (error) {
      if (mounted) showMessage(error.toString(), isError: true);
    } finally {
      _setOfficialBusy(item.resourceId, busy: false);
    }
  }
}
