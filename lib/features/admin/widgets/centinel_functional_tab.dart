import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../core/network/api_error.dart';
import '../repositories/centinel_repository.dart';

part '../centinel/functional_results.dart';

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
/// Panel de pruebas funcionales de Centinel.
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
  void _refresh(VoidCallback update) => setState(update);

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
    _refresh(() {
      _treeLoading = true;
      _treeError = null;
    });
    try {
      final tree = await widget.repository.tree(widget.token);
      if (!mounted) return;
      _refresh(() {
        _tree = tree;
        _treeLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      _refresh(() {
        _treeError = error.message;
        _treeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _refresh(() {
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
      _refresh(() => _history = history);
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
      _refresh(() {
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
    if (!rerunFailed && _selectedFiles != null && _selectedFiles!.isEmpty) {
      return;
    }

    _refresh(() {
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
      _refresh(() {
        _status = 'running';
        _runId = result['run_id'] as String?;
        _starting = false;
      });
      if (_runId != null) _connectStream(_runId!);
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
      if (mounted) _refresh(() => _starting = false);
    } catch (_) {
      _showMessage(
        _tx('centinel.errors_run_start', 'No se pudo iniciar el run'),
        isError: true,
      );
      if (mounted) _refresh(() => _starting = false);
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
            if (mounted && _status == 'running') {
              _refresh(() => _status = 'error');
            }
          },
          onError: (_) {
            if (mounted && _status == 'running') {
              _refresh(() => _status = 'error');
            }
          },
        );
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString();
    if (!mounted) return;
    switch (type) {
      case 'started':
        _refresh(() => _logLines.add('Run iniciado: ${event['target']}'));
      case 'collecting':
        _refresh(() => _logLines.add('collected ${event['count']} items'));
      case 'test':
        final status = (event['status'] ?? '').toString();
        final file = (event['file'] ?? '').toString();
        final name = (event['name'] ?? '').toString();
        final progress = event['progress'] is num
            ? (event['progress'] as num).toInt()
            : 0;
        final traceback = event['traceback'] as String?;
        _refresh(() {
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
          if (traceback != null && traceback.isNotEmpty) {
            _logLines.add(traceback);
          }
        });
      case 'summary':
        _refresh(() => _summary = event);
      case 'done':
        final failed = event['failed_ids'];
        _refresh(() {
          _status = 'idle';
          _failedIds = failed is List
              ? failed.map((e) => e.toString()).toList()
              : const [];
        });
        _loadHistory();
      case 'aborted':
        _refresh(() => _status = 'idle');
        _loadHistory();
      case 'error':
        _refresh(() => _status = 'error');
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
      if (_resultFilter == 'failed') {
        return e.status == 'failed' || e.status == 'error';
      }
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
        PrimaryButton.icon(
          onPressed: (_status == 'running' || nothingSelected || _starting)
              ? null
              : () => _startRun(),
          icon: const Icon(Icons.play_arrow),
          label: Text(_tx('centinel.actions_run', 'Ejecutar')),
        ),
        if (_failedIds.isNotEmpty && _status != 'running')
          SecondaryButton.icon(
            onPressed: _starting ? null : () => _startRun(rerunFailed: true),
            icon: const Icon(Icons.replay),
            label: Text(
              _tx('centinel.actions_rerun_failed', 'Re-run fallidos'),
            ),
          ),
        if (_status == 'running')
          PrimaryButton.tonalIcon(
            onPressed: _abort,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(_tx('centinel.actions_abort', 'Abortar')),
          ),
        SecondaryButton.icon(
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
}
