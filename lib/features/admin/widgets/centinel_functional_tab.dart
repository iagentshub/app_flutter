import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../repositories/centinel_repository.dart';

class _TestEvent {
  const _TestEvent({
    required this.file,
    required this.name,
    required this.status,
    required this.progress,
    this.traceback,
  });

  final String file;
  final String name;
  final String status;
  final int progress;
  final String? traceback;
}

/// Pestaña "Funcionalidad" de Centinel: árbol de módulos pytest, resultados
/// en vivo vía SSE con filtros, log en bruto, e historial — igual que
/// centinel.js en frontend_vanilla.
class CentinelFunctionalTab extends StatefulWidget {
  const CentinelFunctionalTab({
    required this.repository,
    required this.token,
    required this.tx,
    super.key,
  });

  final CentinelRepository repository;
  final String token;
  final String Function(String path, String fallback) tx;

  @override
  State<CentinelFunctionalTab> createState() => _CentinelFunctionalTabState();
}

class _CentinelFunctionalTabState extends State<CentinelFunctionalTab> {
  final _treeSearchController = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _sub;

  Map<String, dynamic>? _tree;
  String? _treeError;
  bool _treeLoading = true;

  List<Map<String, dynamic>> _history = const [];

  Set<String>? _selectedFiles; // null = todos
  String _status = 'idle';
  String? _runId;
  int _progress = 0;
  String _currentFile = '';
  Map<String, dynamic> _summary = const {};
  List<String> _failedIds = const [];
  final List<_TestEvent> _events = [];
  String _resultFilter = 'all';
  bool _logView = false;
  final List<String> _logLines = [];
  bool _starting = false;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void initState() {
    super.initState();
    _loadTree();
    _loadHistory();
    _checkExistingRun();
  }

  @override
  void dispose() {
    _treeSearchController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  List<String> get _allFiles {
    final dirs = (_tree?['dirs'] as List?) ?? const [];
    return dirs
        .expand((d) => ((d as Map)['files'] as List? ?? const []))
        .map((f) => (f as Map)['file'].toString())
        .toList();
  }

  Future<void> _loadTree() async {
    setState(() {
      _treeLoading = true;
      _treeError = null;
    });
    try {
      final tree = await widget.repository.tree(widget.token);
      if (!mounted) return;
      setState(() {
        _tree = tree;
        _treeLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _treeError = error.message;
        _treeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _treeError = _tx(
          'centinel.errors_discover',
          'No se pudo descubrir la suite de tests',
        );
        _treeLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await widget.repository.history(widget.token);
      if (!mounted) return;
      setState(() => _history = history);
    } catch (_) {
      // Historial es informativo; un fallo aquí no bloquea el resto.
    }
  }

  Future<void> _checkExistingRun() async {
    try {
      final status = await widget.repository.status(widget.token);
      if (!mounted) return;
      final runStatus = (status['status'] ?? 'idle').toString();
      final failed = status['failed_ids'];
      setState(() {
        _status = runStatus;
        _runId = status['run_id'] as String?;
        _failedIds = failed is List
            ? failed.map((e) => e.toString()).toList()
            : const [];
      });
      if (runStatus == 'running' && _runId != null) {
        _connectStream(_runId!);
      }
    } catch (_) {
      // Ignorar: el panel funciona igualmente en estado idle.
    }
  }

  String _target() {
    if (_selectedFiles == null) return 'tests/';
    final files = _selectedFiles!.toList();
    return files.join(' ');
  }

  Future<void> _startRun({bool rerunFailed = false}) async {
    if (_status == 'running') return;
    if (!rerunFailed && _selectedFiles != null && _selectedFiles!.isEmpty)
      return;

    setState(() {
      _starting = true;
      _events.clear();
      _logLines.clear();
      _progress = 0;
      _currentFile = '';
      _summary = const {};
    });
    try {
      final result = await widget.repository.run(
        widget.token,
        target: rerunFailed ? 'tests/' : _target(),
        rerunFailed: rerunFailed,
      );
      if (!mounted) return;
      setState(() {
        _status = 'running';
        _runId = result['run_id'] as String?;
        _starting = false;
      });
      if (_runId != null) _connectStream(_runId!);
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
      if (mounted) setState(() => _starting = false);
    } catch (_) {
      _showMessage(
        _tx('centinel.errors_run_start', 'No se pudo iniciar el run'),
        isError: true,
      );
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _abort() async {
    try {
      await widget.repository.abort(widget.token);
      _showMessage(_tx('centinel.toast_run_aborted', 'Run abortado'));
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('centinel.toast_abort_failed', 'No se pudo abortar el run'),
        isError: true,
      );
    }
  }

  void _connectStream(String runId) {
    _sub?.cancel();
    _sub = widget.repository
        .stream(widget.token, runId)
        .listen(
          _handleEvent,
          onDone: () {
            if (mounted && _status == 'running')
              setState(() => _status = 'error');
          },
          onError: (_) {
            if (mounted && _status == 'running')
              setState(() => _status = 'error');
          },
        );
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString();
    if (!mounted) return;
    switch (type) {
      case 'started':
        setState(() => _logLines.add('Run iniciado: ${event['target']}'));
      case 'collecting':
        setState(() => _logLines.add('collected ${event['count']} items'));
      case 'test':
        final status = (event['status'] ?? '').toString();
        final file = (event['file'] ?? '').toString();
        final name = (event['name'] ?? '').toString();
        final progress = event['progress'] is num
            ? (event['progress'] as num).toInt()
            : 0;
        final traceback = event['traceback'] as String?;
        setState(() {
          _events.add(
            _TestEvent(
              file: file,
              name: name,
              status: status,
              progress: progress,
              traceback: traceback,
            ),
          );
          _progress = progress;
          _currentFile = file;
          _logLines.add('$file::$name ${status.toUpperCase()} [$progress%]');
          if (traceback != null && traceback.isNotEmpty)
            _logLines.add(traceback);
        });
      case 'summary':
        setState(() => _summary = event);
      case 'done':
        final failed = event['failed_ids'];
        setState(() {
          _status = 'idle';
          _failedIds = failed is List
              ? failed.map((e) => e.toString()).toList()
              : const [];
        });
        _loadHistory();
      case 'aborted':
        setState(() => _status = 'idle');
        _loadHistory();
      case 'error':
        setState(() => _status = 'error');
        _showMessage(
          (event['message'] ?? 'Error en el run').toString(),
          isError: true,
        );
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  List<_TestEvent> get _filteredEvents {
    if (_resultFilter == 'all') return _events;
    return _events.where((e) {
      if (_resultFilter == 'failed')
        return e.status == 'failed' || e.status == 'error';
      return e.status == _resultFilter;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'passed':
        return const Color(0xFF059669);
      case 'failed':
      case 'error':
        return const Color(0xFFDC2626);
      case 'skipped':
        return const Color(0xFFD97706);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'passed':
        return Icons.check_circle_outline;
      case 'failed':
      case 'error':
        return Icons.cancel_outlined;
      case 'skipped':
        return Icons.remove_circle_outline;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final tree = _buildTreePanel();
    final results = _buildResultsPanel();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildActionsBar(),
        if (_status == 'running') ...[
          const SizedBox(height: 10),
          _buildProgressBar(),
        ],
        if (_summary.isNotEmpty && _status != 'running') ...[
          const SizedBox(height: 10),
          _buildSummaryBar(),
        ],
        const SizedBox(height: 12),
        if (wide)
          SizedBox(
            height: 520,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 280, child: tree),
                const SizedBox(width: 12),
                Expanded(child: results),
              ],
            ),
          )
        else ...[
          SizedBox(height: 320, child: tree),
          const SizedBox(height: 12),
          SizedBox(height: 420, child: results),
        ],
        const SizedBox(height: 16),
        _buildHistory(),
      ],
    );
  }

  Widget _buildActionsBar() {
    final nothingSelected = _selectedFiles != null && _selectedFiles!.isEmpty;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: (_status == 'running' || nothingSelected || _starting)
              ? null
              : () => _startRun(),
          icon: const Icon(Icons.play_arrow),
          label: Text(_tx('centinel.actions_run', 'Ejecutar')),
        ),
        if (_failedIds.isNotEmpty && _status != 'running')
          OutlinedButton.icon(
            onPressed: _starting ? null : () => _startRun(rerunFailed: true),
            icon: const Icon(Icons.replay),
            label: Text(
              _tx('centinel.actions_rerun_failed', 'Re-run fallidos'),
            ),
          ),
        if (_status == 'running')
          FilledButton.tonalIcon(
            onPressed: _abort,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(_tx('centinel.actions_abort', 'Abortar')),
          ),
        OutlinedButton.icon(
          onPressed: () {
            _loadTree();
            _loadHistory();
          },
          icon: const Icon(Icons.refresh),
          label: Text(_tx('admin.refresh', 'Actualizar')),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final hasFailures = _events.any(
      (e) => e.status == 'failed' || e.status == 'error',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: _progress / 100,
            minHeight: 8,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              hasFailures ? const Color(0xFFDC2626) : const Color(0xFF059669),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$_progress% · $_currentFile',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

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
                  onChanged: (_) => setState(() {}),
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
                TextButton(
                  onPressed: _selectAll,
                  child: Text(_tx('centinel.tree_select_all', 'Todo')),
                ),
                TextButton(
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

  void _selectAll() => setState(() => _selectedFiles = null);

  void _deselectAll() => setState(() => _selectedFiles = {});

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
    if (dirs.isEmpty)
      return Center(
        child: Text(_tx('centinel.tree_discovering', 'Descubriendo tests…')),
      );

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
    setState(() {
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
                IconButton(
                  tooltip: _tx(
                    'centinel.results_log_toggle_title',
                    'Ver log en tiempo real',
                  ),
                  onPressed: () => setState(() => _logView = !_logView),
                  icon: Icon(
                    _logView ? Icons.list_alt : Icons.terminal_outlined,
                    size: 18,
                  ),
                  isSelected: _logView,
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
        onSelected: (_) => setState(() => _resultFilter = value),
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
