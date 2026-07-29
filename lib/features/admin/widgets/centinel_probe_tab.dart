import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../repositories/centinel_repository.dart';
import 'centinel_chart.dart';

/// Pestaña "Buscar límite" de Centinel: sube la carga paso a paso hasta el
/// primer error, para encontrar el techo estable de la plataforma — igual
/// que la sección "probe" de centinel-stress.js en frontend_vanilla.
class CentinelProbeTab extends StatefulWidget {
  const CentinelProbeTab({required this.repository, required this.token, required this.tx, super.key});

  final CentinelRepository repository;
  final String token;
  final String Function(String path, String fallback) tx;

  @override
  State<CentinelProbeTab> createState() => _CentinelProbeTabState();
}

class _CentinelProbeTabState extends State<CentinelProbeTab> {
  final _startController = TextEditingController(text: '10');
  final _stepController = TextEditingController(text: '50');
  final _concurrencyController = TextEditingController(text: '0');
  final _timeoutController = TextEditingController(text: '10');
  int _duration = 30;

  bool _running = false;
  bool _starting = false;
  Timer? _pollTimer;
  List<Map<String, dynamic>> _ticks = const [];
  List<Map<String, dynamic>> _steps = const [];
  Map<String, dynamic>? _verdict;
  String? _finalStatus;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void dispose() {
    _pollTimer?.cancel();
    _startController.dispose();
    _stepController.dispose();
    _concurrencyController.dispose();
    _timeoutController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _ticks = const [];
      _steps = const [];
      _verdict = null;
      _finalStatus = null;
    });
    final config = {
      'start_users': int.tryParse(_startController.text.trim()) ?? 10,
      'step': int.tryParse(_stepController.text.trim()) ?? 50,
      'duration': _duration,
      'max_concurrency': int.tryParse(_concurrencyController.text.trim()) ?? 0,
      'timeout': double.tryParse(_timeoutController.text.trim()) ?? 10.0,
    };
    try {
      await widget.repository.probeStart(widget.token, config);
      if (!mounted) return;
      setState(() {
        _running = true;
        _starting = false;
      });
      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) => _poll());
      _poll();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
      if (mounted) setState(() => _starting = false);
    } catch (_) {
      _showMessage(_tx('centinel.probe_start_error', 'No se pudo iniciar la búsqueda'), isError: true);
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _abort() async {
    try {
      await widget.repository.probeAbort(widget.token);
    } catch (_) {
      // El siguiente poll refleja el estado real.
    }
    _setIdle();
  }

  void _setIdle() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (mounted) setState(() => _running = false);
  }

  Future<void> _poll() async {
    try {
      final data = await widget.repository.probeStatus(widget.token);
      if (!mounted) return;
      final ticks = (data['ticks'] as List?) ?? const [];
      final steps = (data['steps'] as List?) ?? const [];
      final status = (data['status'] ?? 'idle').toString();
      setState(() {
        _ticks = ticks.cast<Map<String, dynamic>>();
        _steps = steps.cast<Map<String, dynamic>>();
      });
      if (status != 'running') {
        setState(() {
          _finalStatus = status;
          _verdict = data['verdict'] as Map<String, dynamic>?;
        });
        _setIdle();
      }
    } catch (_) {
      // Silencioso: el siguiente tick reintenta.
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? Colors.red.shade700 : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            if (!_running)
              FilledButton.icon(
                onPressed: _starting ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(_tx('centinel.actions_probe_start', 'Iniciar búsqueda')),
              )
            else
              FilledButton.tonalIcon(
                onPressed: _abort,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(_tx('centinel.actions_probe_stop', 'Detener')),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildConfigCard(),
        const SizedBox(height: 12),
        _buildChartCard(),
        if (_verdict != null || _finalStatus == 'aborted') ...[
          const SizedBox(height: 12),
          _buildVerdict(),
        ],
        if (_steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildStepsTable(),
        ],
      ],
    );
  }

  Widget _buildConfigCard() {
    final disabled = _running;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _startController,
                    enabled: !disabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _tx('centinel.probe_start_label', 'Inicio')),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _stepController,
                    enabled: !disabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _tx('centinel.probe_step_label', 'Paso')),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _concurrencyController,
                    enabled: !disabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: _tx('centinel.probe_concurrency_label', 'Concurrencia máx (0=∞)')),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _timeoutController,
                    enabled: !disabled,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: _tx('centinel.probe_timeout_label', 'Timeout/req (s)')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_tx('centinel.probe_duration_step_label', 'Duración por paso'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                (10, '10s'),
                (30, '30s'),
                (60, '1min'),
              ].map((opt) {
                return ChoiceChip(
                  label: Text(opt.$2),
                  selected: _duration == opt.$1,
                  onSelected: disabled ? null : (_) => setState(() => _duration = opt.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              _tx('centinel.probe_hint', 'Lanza pruebas secuenciales aumentando el número de usuarios de paso en paso. Se detiene al primer error, mostrando el límite estable de la plataforma.'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard() {
    final rps = _ticks.map((t) => (t['rps'] as num? ?? 0).toDouble()).toList();
    final avg = _ticks.map((t) => (t['avg_s'] as num? ?? 0).toDouble()).toList();
    final users = _ticks.map((t) => (t['users'] as num? ?? 0).toDouble()).toList();
    final errors = _ticks.map((t) => (t['errors'] as num? ?? 0).toDouble()).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tx('centinel.probe_chart_title', 'Evolución en tiempo real'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                _legendItem(const Color(0xFF22C55E), _tx('centinel.chart_legend_rps', 'req/s')),
                _legendItem(const Color(0xFF6366F1), _tx('centinel.probe_legend_avg', 'Avg s')),
                _legendItem(const Color(0xFFF97316), _tx('centinel.chart_legend_users', 'Usuarios')),
                _legendItem(const Color(0xFFEF4444), _tx('centinel.errors_table_col_error', 'Error')),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: CentinelChart(
                emptyLabel: _tx('centinel.probe_chart_empty', 'Inicia la búsqueda para ver la gráfica'),
                series: [
                  ChartSeries(values: rps, color: const Color(0xFF22C55E)),
                  ChartSeries(values: avg, color: const Color(0xFF6366F1), ownScale: false),
                  ChartSeries(values: users, color: const Color(0xFFF97316)),
                  ChartSeries(values: errors, color: const Color(0xFFEF4444), style: ChartSeriesStyle.dots),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildVerdict() {
    final v = _verdict;
    if (_finalStatus == 'aborted') {
      final stable = v?['stable_users'];
      return _verdictBanner(
        Colors.orange,
        '⚠️ ${_tx('centinel.probe_stopped_manually', 'Detenido manualmente.')}${stable != null ? ' ${_tx('centinel.probe_last_stable', 'Último nivel estable: {n} usuarios.').replaceAll('{n}', '$stable')}' : ''}',
      );
    }
    if (v == null) return const SizedBox.shrink();

    final stableUsers = v['stable_users'];
    final breakUsers = v['break_users'];
    final errorRate = v['error_rate'];
    final errPct = errorRate is num ? (errorRate * 100).toStringAsFixed(1) : '?';
    final breakTotal = v['break_total'];

    if (breakUsers == null) {
      return _verdictBanner(
        Colors.green,
        '✅ ${_tx('centinel.probe_no_errors_until', 'Sin errores hasta {n} usuarios.').replaceAll('{n}', '${stableUsers ?? '?'}')} ${_tx('centinel.probe_increase_step_hint', 'Aumenta el paso para seguir buscando el límite.')}',
      );
    }
    if (stableUsers == null) {
      return _verdictBanner(
        Colors.red,
        '❌ ${_tx('centinel.probe_first_failure_at', 'Primer fallo en {n} usuarios').replaceAll('{n}', '$breakUsers')}'
        '${breakTotal != null ? ' · ${_tx('centinel.probe_concurrent_requests', '{n} peticiones concurrentes').replaceAll('{n}', '$breakTotal')}' : ''}'
        ' · ${_tx('centinel.probe_error_percent', '{pct}% de error').replaceAll('{pct}', errPct)}',
      );
    }
    return _verdictBanner(
      Colors.orange,
      '✅ ${_tx('centinel.probe_stable_until', 'Estable hasta {n} usuarios').replaceAll('{n}', '$stableUsers')} → '
      '❌ ${_tx('centinel.probe_first_failure_at', 'Primer fallo en {n} usuarios').replaceAll('{n}', '$breakUsers')}'
      '${breakTotal != null ? ' · ${_tx('centinel.probe_concurrent_requests', '{n} peticiones concurrentes').replaceAll('{n}', '$breakTotal')}' : ''}'
      ' · ${_tx('centinel.probe_error_percent', '{pct}% de error').replaceAll('{pct}', errPct)}',
    );
  }

  Widget _verdictBanner(Color color, String text) {
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildStepsTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: [
                  DataColumn(label: Text(_tx('centinel.probe_col_users', 'Usuarios'))),
                  DataColumn(label: Text(_tx('centinel.probe_col_rps', 'req/s'))),
                  DataColumn(label: Text(_tx('centinel.summary_stat_errors', 'Errores'))),
                  DataColumn(label: Text(_tx('centinel.probe_legend_avg', 'Avg s'))),
                  DataColumn(label: Text(_tx('centinel.probe_col_status', 'Estado'))),
                ],
                rows: _steps.map((s) {
                  final status = (s['status'] ?? '').toString();
                  final total = s['total'] ?? 0;
                  final errors = s['errors'] ?? 0;
                  final errPct = (total is num && total > 0) ? ((errors as num) / total * 100).toStringAsFixed(1) : null;
                  final avgS = s['avg_s'];
                  Color statusColor;
                  String statusText;
                  switch (status) {
                    case 'ok':
                      statusColor = const Color(0xFF059669);
                      statusText = '✓ ${_tx('centinel.probe_status_ok', 'Estable')}';
                    case 'fail':
                      statusColor = const Color(0xFFDC2626);
                      statusText = '✗ ${_tx('centinel.probe_status_fail', 'Errores')}';
                    default:
                      statusColor = Colors.grey;
                      statusText = _tx('centinel.probe_status_running', 'Probando…');
                  }
                  return DataRow(
                    cells: [
                      DataCell(Text('${s['users'] ?? '-'}', style: const TextStyle(fontWeight: FontWeight.w700))),
                      DataCell(Text('${s['rps'] ?? '-'}')),
                      DataCell(Text(errors is num && errors > 0 ? '$errors (${errPct ?? '-'}%)' : '0')),
                      DataCell(Text(avgS is num ? avgS.toStringAsFixed(3) : '-')),
                      DataCell(Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
