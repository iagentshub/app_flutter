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
          '${_tx('centinel.results_filter_passed', 'Pasados')}: $passed',
          const Color(0xFF059669),
        ),
        _summaryChip(
          '${_tx('centinel.results_filter_failed', 'Fallidos')}: $failed',
          const Color(0xFFDC2626),
        ),
        _summaryChip(
          '${_tx('centinel.results_filter_skipped', 'Omitidos')}: $skipped',
          const Color(0xFFD97706),
        ),
        if (error is num && error > 0)
          _summaryChip('Error: $error', const Color(0xFFDC2626)),
        if (duration != null) _summaryChip('${duration}s', Colors.grey),
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
          fontSize: 12,
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
                  _tx('centinel.tree_modules_title', 'Módulos'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _treeSearchController,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: _tx(
                      'centinel.tree_filter_placeholder',
                      'Filtrar…',
                    ),
                    prefixIcon: const Icon(Icons.search, size: 18),
                  ),
                  onChanged: (_) => _refresh(() {}),
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
                  child: Text(_tx('centinel.tree_select_all', 'Todo')),
                ),
                TertiaryButton(
                  onPressed: _deselectAll,
                  child: Text(_tx('centinel.tree_deselect_all', 'Ninguno')),
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

  void _selectAll() => _refresh(() => _selectedFiles = null);

  void _deselectAll() => _refresh(() => _selectedFiles = {});

  Widget _buildTreeBody() {
    if (_treeLoading) return const Center(child: CircularProgressIndicator());
    if (_treeError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            _treeError!,
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
      );
    }
    final dirs = (_tree?['dirs'] as List?) ?? const [];
    if (dirs.isEmpty) {
      return Center(
        child: Text(_tx('centinel.tree_discovering', 'Descubriendo tests…')),
      );
    }

    final q = _treeSearchController.text.trim().toLowerCase();
    return ListView(
      children: dirs.map((raw) {
        final dir = raw as Map;
        final files = (dir['files'] as List? ?? const []).cast<Map>().where((
          f,
        ) {
          if (q.isEmpty) return true;
          return f['file'].toString().toLowerCase().contains(q);
        }).toList();
        if (files.isEmpty) return const SizedBox.shrink();
        return ExpansionTile(
          title: Text(
            dir['dir'].toString(),
            style: const TextStyle(fontSize: 13),
          ),
          trailing: Text(
            '${dir['count']}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          initiallyExpanded: q.isNotEmpty,
          children: files.map((f) {
            final file = f['file'].toString();
            final checked =
                _selectedFiles == null || _selectedFiles!.contains(file);
            return CheckboxListTile(
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              value: checked,
              title: Text(
                file.split('/').last,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
              secondary: Text(
                '${f['count']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              onChanged: (value) => _onFileCheck(file, value ?? true),
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  void _onFileCheck(String file, bool checked) {
    _refresh(() {
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
                  _tx('centinel.results_title', 'Resultados'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _filterTab(
                          'all',
                          _tx('centinel.results_filter_all', 'Todos'),
                        ),
                        _filterTab(
                          'failed',
                          _tx('centinel.results_filter_failed', 'Fallidos'),
                        ),
                        _filterTab(
                          'passed',
                          _tx('centinel.results_filter_passed', 'Pasados'),
                        ),
                        _filterTab(
                          'skipped',
                          _tx('centinel.results_filter_skipped', 'Omitidos'),
                        ),
                      ],
                    ),
                  ),
                ),
                AppIconButton(
                  tooltip: _tx(
                    'centinel.results_log_toggle_title',
                    'Ver log en tiempo real',
                  ),
                  onPressed: () => _refresh(() => _logView = !_logView),
                  icon: Icon(
                    _logView ? Icons.list_alt : Icons.terminal_outlined,
                    size: 18,
                  ),
                  isSelected: _logView,
                ),
                AppIconButton(
                  tooltip: _tx('centinel.results_copy_log', 'Copiar log'),
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
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => _refresh(() => _resultFilter = value),
      ),
    );
  }

  Widget _buildLogPane() {
    if (_logLines.isEmpty) {
      return Center(
        child: Text(
          _tx(
            'centinel.results_empty_state',
            'Ejecuta los tests para ver los resultados',
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _logLines.length,
      itemBuilder: (context, index) => Text(
        _logLines[index],
        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
      ),
    );
  }

  Widget _buildResultsList() {
    final items = _filteredEvents;
    if (items.isEmpty) {
      return Center(
        child: Text(
          _tx(
            'centinel.results_empty_state',
            'Ejecuta los tests para ver los resultados',
          ),
        ),
      );
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
                fontFamily: 'monospace',
                fontSize: 11,
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
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: e.traceback != null && e.traceback!.isNotEmpty
              ? Text(
                  e.traceback!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                )
              : null,
        );
      },
    );
  }

  Widget _buildHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tx('centinel.history_title', 'Historial reciente'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_history.isEmpty)
              Text(_tx('centinel.history_empty', 'Sin ejecuciones previas'))
            else
              ..._history.map((entry) {
                final status = (entry['status'] ?? '-').toString();
                final target = (entry['target'] ?? '-').toString();
                final summary =
                    entry['summary'] as Map<String, dynamic>? ?? const {};
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
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF059669),
                  ),
                  title: Text(
                    target,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  subtitle: Text(
                    '$status · $passed passed · $failed failed · $skipped skipped',
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
