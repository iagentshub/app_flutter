import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/lazy_expansion_tile.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../../../utils/i18n.dart';
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
  final String Function(String path) tx;

  @override
  State<CentinelFunctionalTab> createState() => _CentinelFunctionalTabState();
}

class _CentinelFunctionalTabState extends State<CentinelFunctionalTab>
    with StateMessaging {
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

  /// false = modo selección (solo "Módulos", sin resultados). true = modo
  /// resultados (solo "Resultados", en vivo o ya terminados) — nunca ambos a
  /// la vez. El botón principal de la barra de acciones es quien conduce la
  /// transición: Ejecutar (false→true) y Reiniciar (true→false); mientras
  /// está en true y _status == 'running' el mismo botón hace de Abortar.
  bool _showingResults = false;

  String _tx(String path) => widget.tx(path);

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
    refresh(() {
      _treeLoading = true;
      _treeError = null;
    });
    try {
      final tree = await widget.repository.tree(widget.token);
      if (!mounted) return;
      refresh(() {
        _tree = tree;
        _treeLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      refresh(() {
        _treeError = error.message;
        _treeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _treeError = _tx('centinel.errors_discover');
        _treeLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await widget.repository.history(widget.token);
      if (!mounted) return;
      refresh(() => _history = history);
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
      refresh(() {
        _status = runStatus;
        _runId = status['run_id'] as String?;
        _failedIds = failed is List
            ? failed.map((e) => e.toString()).toList()
            : const [];
        if (runStatus != 'idle') _showingResults = true;
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

    refresh(() {
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
      refresh(() {
        _status = 'running';
        _runId = result['run_id'] as String?;
        _starting = false;
        _showingResults = true;
      });
      if (_runId != null) _connectStream(_runId!);
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
      if (mounted) refresh(() => _starting = false);
    } catch (_) {
      showMessage(_tx('centinel.errors_run_start'), isError: true);
      if (mounted) refresh(() => _starting = false);
    }
  }

  Future<void> _abort() async {
    try {
      await widget.repository.abort(widget.token);
      showMessage(_tx('centinel.toast_run_aborted'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('centinel.toast_abort_failed'), isError: true);
    }
  }

  /// Vuelve al modo selección — la selección de ficheros se conserva, solo se
  /// descarta lo relativo al run ya visto (eventos, log, resumen).
  void _resetToSelecting() {
    _sub?.cancel();
    refresh(() {
      _showingResults = false;
      _status = 'idle';
      _runId = null;
      _events.clear();
      _logLines.clear();
      _summary = const {};
      _progress = 0;
      _currentFile = '';
      _failedIds = const [];
    });
  }

  void _connectStream(String runId) {
    _sub?.cancel();
    _sub = widget.repository
        .stream(widget.token, runId)
        .listen(
          _handleEvent,
          onDone: () => _handleStreamDropped(),
          onError: (_) => _handleStreamDropped(),
        );
  }

  /// La conexión SSE se cerró sin un evento terminal (done/aborted/error) —
  /// p.ej. un proxy intermedio la cortó. El run puede seguir vivo en el
  /// backend, así que avisamos en vez de dejar la UI en "running" para
  /// siempre, pero sin fingir que el run en sí falló.
  void _handleStreamDropped() {
    if (!mounted || _status != 'running') return;
    refresh(() => _status = 'error');
    showMessage(_tx('centinel.toast_stream_dropped'), isError: true);
  }

  void _handleEvent(Map<String, dynamic> event) {
    final type = (event['type'] ?? '').toString();
    if (!mounted) return;
    switch (type) {
      case 'started':
        refresh(() => _logLines.add('Run iniciado: ${event['target']}'));
      case 'collecting':
        refresh(() => _logLines.add('collected ${event['count']} items'));
      case 'test':
        final status = (event['status'] ?? '').toString();
        final file = (event['file'] ?? '').toString();
        final name = (event['name'] ?? '').toString();
        final progress = event['progress'] is num
            ? (event['progress'] as num).toInt()
            : 0;
        final traceback = event['traceback'] as String?;
        refresh(() {
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
        refresh(() => _summary = event);
      case 'done':
        final failed = event['failed_ids'];
        refresh(() {
          _status = 'idle';
          _failedIds = failed is List
              ? failed.map((e) => e.toString()).toList()
              : const [];
        });
        _loadHistory();
      case 'aborted':
        refresh(() => _status = 'idle');
        _loadHistory();
      case 'error':
        refresh(() => _status = 'error');
        showMessage(
          (event['message'] ?? tr('admin.centinel_run_error')).toString(),
          isError: true,
        );
    }
  }

  Future<void> _copyLog() async {
    await Clipboard.setData(ClipboardData(text: _logLines.join('\n')));
    showMessage(_tx('centinel.toast_log_copied'));
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
        return FncColors.success;
      case 'failed':
      case 'error':
        return FncColors.danger;
      case 'skipped':
        return FncColors.labelDevelopment;
      default:
        return FncColors.materialGrey;
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
    // Nunca ambos a la vez: selección de tests O resultados, nunca las dos.
    final panel = _showingResults ? _buildResultsPanel() : _buildTreePanel();

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
        SizedBox(height: wide ? 520 : 420, child: panel),
      ],
    );
  }

  Widget _buildActionsBar() {
    final nothingSelected = _selectedFiles != null && _selectedFiles!.isEmpty;

    // Un único botón conduce el ciclo completo: Ejecutar (selección→en vivo)
    // → Abortar (mientras corre) → Reiniciar (resultados→vuelta a selección).
    final Widget primaryAction;
    if (!_showingResults) {
      primaryAction = PrimaryButton.icon(
        onPressed: (nothingSelected || _starting) ? null : () => _startRun(),
        icon: const Icon(Icons.play_arrow),
        label: Text(_tx('centinel.actions_run')),
      );
    } else if (_status == 'running') {
      primaryAction = PrimaryButton.tonalIcon(
        onPressed: _abort,
        icon: const Icon(Icons.stop_circle_outlined),
        label: Text(_tx('centinel.actions_abort')),
      );
    } else {
      primaryAction = PrimaryButton.icon(
        onPressed: _resetToSelecting,
        icon: const Icon(Icons.restart_alt),
        label: Text(_tx('centinel.actions_restart')),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        primaryAction,
        if (_showingResults && _status != 'running' && _failedIds.isNotEmpty)
          SecondaryButton.icon(
            onPressed: _starting ? null : () => _startRun(rerunFailed: true),
            icon: const Icon(Icons.replay),
            label: Text(_tx('centinel.actions_rerun_failed')),
          ),
        SecondaryButton.icon(
          onPressed: _showHistoryDialog,
          icon: const Icon(Icons.history),
          label: Text(_tx('centinel.history_title')),
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
            backgroundColor: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(
              hasFailures ? FncColors.danger : FncColors.success,
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
