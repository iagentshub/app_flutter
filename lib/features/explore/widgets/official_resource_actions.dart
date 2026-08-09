part of '../pages/explore_page.dart';

extension _OfficialResourceActions on _ExplorePageState {
  Future<Set<String>?> _selectOfficialComponents(
    ExploreItem item, {
    required bool hubOnly,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty || item.officialPackageId.isEmpty) {
      return null;
    }
    _setOfficialBusy(item.resourceId, busy: true);
    Map<String, dynamic> package;
    try {
      package = await _officialRepository.getPackage(
        token,
        item.officialPackageId,
      );
    } catch (error) {
      if (mounted) showMessage(error.toString(), isError: true);
      return null;
    } finally {
      _setOfficialBusy(item.resourceId, busy: false);
    }
    if (!mounted) return null;
    final version = package['version'];
    if (version is! Map) return null;
    final components =
        (version['components'] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => entry.cast<String, dynamic>())
            .where((component) => !hubOnly || _hubInstallable(component))
            .toList()
          ..sort((a, b) {
            final type = (a['component_type']?.toString() ?? '').compareTo(
              b['component_type']?.toString() ?? '',
            );
            return type != 0
                ? type
                : (a['name']?.toString() ?? '').compareTo(
                    b['name']?.toString() ?? '',
                  );
          });
    final byId = {
      for (final component in components)
        component['component_id'].toString(): component,
    };
    if (!byId.containsKey(item.officialComponentId)) return null;
    final explicit = <String>{item.officialComponentId};

    Set<String> closure() {
      final selected = <String>{...explicit};
      final pending = [...explicit];
      while (pending.isNotEmpty) {
        final component = byId[pending.removeLast()];
        for (final dependency
            in (component?['dependencies'] as List? ?? const [])) {
          final id = dependency.toString();
          if (byId.containsKey(id) && selected.add(id)) pending.add(id);
        }
      }
      return selected;
    }

    return showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final selected = closure();
          return AlertDialog(
            title: Text(
              _tx('official.choose_content', 'Elegir contenido de la fuente'),
            ),
            content: SizedBox(
              width: dialogContentWidth(context, 640),
              height: dialogContentHeight(context, 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package['name']?.toString() ?? item.officialPackageName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final component in components)
                          CheckboxListTile(
                            value: selected.contains(
                              component['component_id'].toString(),
                            ),
                            title: Text(component['name']?.toString() ?? ''),
                            subtitle: Text(
                              [
                                _typeChipLabel(
                                  component['component_type']?.toString() ?? '',
                                ),
                                if (selected.contains(
                                      component['component_id'].toString(),
                                    ) &&
                                    !explicit.contains(
                                      component['component_id'].toString(),
                                    ))
                                  _tx(
                                    'official.required_dependency',
                                    'Dependencia requerida',
                                  ),
                              ].join(' · '),
                            ),
                            onChanged:
                                selected.contains(
                                      component['component_id'].toString(),
                                    ) &&
                                    !explicit.contains(
                                      component['component_id'].toString(),
                                    )
                                ? null
                                : (checked) => setDialogState(() {
                                    final id = component['component_id']
                                        .toString();
                                    if (checked == true) {
                                      explicit.add(id);
                                    } else {
                                      explicit.remove(id);
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
                onPressed: () => Navigator.pop(context),
                child: Text(_tx('common.cancel', 'Cancelar')),
              ),
              PrimaryButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, selected),
                child: Text(_tx('official.use_selection', 'Usar selección')),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hubInstallable(Map<String, dynamic> component) {
    final type = component['component_type']?.toString() ?? '';
    if (const {
      'agent',
      'skill',
      'knowledge',
      'prompt',
      'workflow',
    }.contains(type)) {
      return true;
    }
    if (type != 'tool') return false;
    final path = component['source_path']?.toString().toLowerCase() ?? '';
    return path.endsWith('.py') || path.endsWith('.sh');
  }

  Future<void> _linkOfficialResource(ExploreItem item) async {
    final ids = await _selectOfficialComponents(item, hubOnly: true);
    if (ids == null || ids.isEmpty || !mounted) return;
    await _runAction(_controller.link(item, officialComponentIds: ids));
  }

  Future<void> _useOfficialResource(ExploreItem item) async {
    final token = _token;
    if (token == null || token.isEmpty || item.officialPackageId.isEmpty) {
      return;
    }
    if (_officialBusyKeys.contains(item.resourceId)) return;
    final ids = await _selectOfficialComponents(item, hubOnly: true);
    if (ids == null || ids.isEmpty || !mounted) return;
    _setOfficialBusy(item.resourceId, busy: true);
    try {
      final result = await _officialRepository.copy(
        token,
        item.officialPackageId,
        ids,
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
    final ids = await _selectOfficialComponents(item, hubOnly: false);
    if (ids == null || ids.isEmpty || !mounted) return;
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
    await _exportOfficialResource(item, target, ids);
  }

  Future<void> _exportOfficialResource(
    ExploreItem item,
    String target,
    Set<String> ids,
  ) async {
    final token = _token;
    if (token == null || token.isEmpty || item.officialPackageId.isEmpty) {
      return;
    }
    if (_officialBusyKeys.contains(item.resourceId)) return;
    _setOfficialBusy(item.resourceId, busy: true);
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
