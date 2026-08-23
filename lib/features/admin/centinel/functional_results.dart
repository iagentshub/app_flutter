part of '../widgets/centinel_functional_tab.dart';

extension _CentinelFunctionalResults on _CentinelFunctionalTabState {
  Widget _buildSummaryBar() {
    final passed = _summary['passed'] ?? 0;
    final failed = _summary['failed'] ?? 0;
    final skipped = _summary['skipped'] ?? 0;
    final error = _summary['error'] ?? 0;
    final duration = _summary['duration_s'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _summaryChip(
          '${_tx('centinel.results_filter_passed')}: $passed',
          FncColors.success,
        ),
        _summaryChip(
          '${_tx('centinel.results_filter_failed')}: $failed',
          FncColors.danger,
        ),
        _summaryChip(
          '${_tx('centinel.results_filter_skipped')}: $skipped',
          FncColors.labelDevelopment,
        ),
        if (error is num && error > 0)
          _summaryChip('Error: $error', FncColors.danger),
        if (duration != null)
          _summaryChip('${duration}s', FncColors.materialGrey),
      ],
    );
  }

  Widget _summaryChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: FncFonts.size12,
        ),
      ),
    );
  }

  Widget _buildTreePanel() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tx('centinel.tree_modules_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _treeSearchController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: _tx('centinel.tree_filter_placeholder'),
                    prefixIcon: const Icon(Icons.search, size: 18),
                  ),
                  onChanged: (_) => refresh(() {}),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildTreeBody()),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                TertiaryButton(
                  onPressed: _selectAll,
                  child: Text(_tx('centinel.tree_select_all')),
                ),
                TertiaryButton(
                  onPressed: _deselectAll,
                  child: Text(_tx('centinel.tree_deselect_all')),
                ),
                const Spacer(),
                Text(
                  _selectionLabel(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _selectionLabel() {
    final total = _allFiles.length;
    if (total == 0) return '';
    final selected = _selectedFiles?.length ?? total;
    return selected == total ? '$total' : '$selected/$total';
  }

  void _selectAll() => refresh(() => _selectedFiles = null);

  void _deselectAll() => refresh(() => _selectedFiles = {});

  Widget _buildTreeBody() {
    if (_treeLoading) return const Center(child: CircularProgressIndicator());
    if (_treeError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _treeError!,
            style: TextStyle(color: FncColors.materialRed.shade700),
          ),
        ),
      );
    }
    final dirs = (_tree?['dirs'] as List?) ?? const [];
    if (dirs.isEmpty) {
      return Center(child: Text(_tx('centinel.tree_discovering')));
    }

    final q = _treeSearchController.text.trim().toLowerCase();
    // El filtro se aplica antes de construir: un directorio sin coincidencias
    // no debe ocupar una fila vacía en la lista, que es lo que hacía el
    // `SizedBox.shrink()` que devolvía el map.
    final visibleDirs = <(String, String, List<Map>)>[];
    for (final raw in dirs) {
      final dir = raw as Map;
      final files = (dir['files'] as List? ?? const [])
          .cast<Map>()
          .where(
            (f) => q.isEmpty || f['file'].toString().toLowerCase().contains(q),
          )
          .toList();
      if (files.isEmpty) continue;
      visibleDirs.add((dir['dir'].toString(), '${dir['count']}', files));
    }

    return ListView.builder(
      itemCount: visibleDirs.length,
      itemBuilder: (context, index) {
        final (name, count, files) = visibleDirs[index];
        return LazyExpansionTile(
          // La búsqueda forma parte de la clave: al cambiarla, un grupo que
          // estaba abierto por coincidir debe reevaluar si sigue abierto.
          key: ValueKey('$name|$q'),
          title: Text(name, style: const TextStyle(fontSize: FncFonts.size13)),
          trailing: Text(count, style: Theme.of(context).textTheme.bodySmall),
          initiallyExpanded: q.isNotEmpty,
          childrenBuilder: () => [
            for (final f in files)
              _buildFileCheckbox(
                context,
                f['file'].toString(),
                '${f['count']}',
              ),
          ],
        );
      },
    );
  }

  Widget _buildFileCheckbox(BuildContext context, String file, String count) {
    final checked = _selectedFiles == null || _selectedFiles!.contains(file);
    return CheckboxListTile(
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
      value: checked,
      title: Text(
        file.split('/').last,
        style: FncFonts.code,
        overflow: TextOverflow.ellipsis,
      ),
      secondary: Text(count, style: Theme.of(context).textTheme.bodySmall),
      onChanged: (value) => _onFileCheck(file, value ?? true),
    );
  }

  void _onFileCheck(String file, bool checked) {
    refresh(() {
      if (checked) {
        if (_selectedFiles != null) _selectedFiles!.add(file);
      } else {
        _selectedFiles ??= {..._allFiles};
        _selectedFiles!.remove(file);
      }
    });
  }

  Widget _buildResultsPanel() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            child: Row(
              children: [
                Text(
                  _tx('centinel.results_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterTab('all', _tx('centinel.results_filter_all')),
                        _filterTab(
                          'failed',
                          _tx('centinel.results_filter_failed'),
                        ),
                        _filterTab(
                          'passed',
                          _tx('centinel.results_filter_passed'),
                        ),
                        _filterTab(
                          'skipped',
                          _tx('centinel.results_filter_skipped'),
                        ),
                      ],
                    ),
                  ),
                ),
                AppIconButton(
                  tooltip: _tx('centinel.results_log_toggle_title'),
                  onPressed: () => refresh(() => _logView = !_logView),
                  icon: Icon(
                    _logView ? Icons.list_alt : Icons.terminal_outlined,
                    size: 18,
                  ),
                  isSelected: _logView,
                ),
                AppIconButton(
                  tooltip: _tx('centinel.results_copy_log'),
                  onPressed: _logLines.isEmpty ? null : _copyLog,
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _logView ? _buildLogPane() : _buildResultsList()),
        ],
      ),
    );
  }

  Widget _filterTab(String value, String label) {
    final selected = _resultFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: FncFonts.size12)),
        selected: selected,
        onSelected: (_) => refresh(() => _resultFilter = value),
      ),
    );
  }

  Widget _buildLogPane() {
    if (_logLines.isEmpty) {
      return Center(child: Text(_tx('centinel.results_empty_state')));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _logLines.length,
      itemBuilder: (context, index) =>
          Text(_logLines[index], style: FncFonts.codeSmall),
    );
  }

  Widget _buildResultsList() {
    final items = _filteredEvents;
    if (items.isEmpty) {
      return Center(child: Text(_tx('centinel.results_empty_state')));
    }
    final byFile = <String, List<_TestEvent>>{};
    for (final e in items) {
      byFile.putIfAbsent(e.file, () => []).add(e);
    }
    // Lista aplanada de filas (encabezado de fichero o evento de test) para
    // que ListView.builder solo construya las filas visibles: con cientos de
    // eventos SSE llegando en vivo, un ListView(children:[...Column/map]) los
    // construiría todos en cada setState.
    final rows = <Object>[];
    for (final entry in byFile.entries) {
      rows.add(entry.key);
      rows.addAll(entry.value);
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Text(
              row,
              style: const TextStyle(
                fontFamily: FncFonts.monospace,
                fontSize: FncFonts.size11,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }
        final e = row as _TestEvent;
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            _statusIcon(e.status),
            color: _statusColor(e.status),
            size: 18,
          ),
          title: Text(
            e.name,
            style: const TextStyle(fontSize: FncFonts.size12),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: e.traceback != null && e.traceback!.isNotEmpty
              ? Text(
                  e.traceback!,
                  style: FncFonts.codeMicro,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        );
      },
    );
  }

  Future<void> _showHistoryDialog() async {
    await _loadHistory();
    if (!mounted) return;
    await showAppDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(_tx('centinel.history_title')),
          content: SizedBox(
            width: 480,
            child: _buildHistoryList(setDialogState),
          ),
          actions: [
            TertiaryButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_tx('common.close')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList(StateSetter setDialogState) {
    if (_history.isEmpty) {
      return Text(_tx('centinel.history_empty'));
    }
    return ListView(
      shrinkWrap: true,
      children: _history.map((entry) {
        final runId = (entry['run_id'] ?? '').toString();
        final status = (entry['status'] ?? '-').toString();
        final target = (entry['target'] ?? '-').toString();
        final summary = entry['summary'] as Map<String, dynamic>? ?? const {};
        final passed = summary['passed'] ?? 0;
        final failed = summary['failed'] ?? 0;
        final skipped = summary['skipped'] ?? 0;
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            status == 'aborted'
                ? Icons.stop_circle_outlined
                : Icons.check_circle_outline,
            color: failed is num && failed > 0
                ? FncColors.danger
                : FncColors.success,
          ),
          title: Text(target, style: FncFonts.code),
          subtitle: Text(
            '$status · $passed passed · $failed failed · $skipped skipped',
          ),
          trailing: AppIconButton(
            tooltip: _tx('centinel.history_delete_action'),
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: () => _deleteHistoryEntry(runId, setDialogState),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _deleteHistoryEntry(
    String runId,
    StateSetter setDialogState,
  ) async {
    final confirmed = await showConfirmActionDialog(
      context,
      title: _tx('centinel.history_delete_title'),
      message: _tx('centinel.history_delete_body'),
      cancelLabel: _tx('common.cancel'),
      confirmLabel: _tx('common.delete'),
      destructive: true,
    );
    if (!confirmed) return;
    try {
      await widget.repository.deleteHistoryEntry(widget.token, runId);
      _history = _history
          .where((h) => (h['run_id'] ?? '').toString() != runId)
          .toList();
      setDialogState(() {});
    } catch (_) {
      showMessage(_tx('centinel.history_delete_failed'), isError: true);
    }
  }
}
