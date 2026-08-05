import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

import '../../../core/network/api_error.dart';
import '../repositories/centinel_repository.dart';
import 'centinel_chart.dart';

part '../centinel/stress_results.dart';

const _predefinedEndpoints = [
  '/api/auth/me',
  '/api/agents',
  '/api/connections',
  '/api/skills/private',
  '/api/knowledge',
];

/// Pestaña "Rendimiento" de Centinel: prueba de estrés configurable con
/// gráfica en vivo, resumen y tabla de errores — igual que
/// El estado se sondea por HTTP (no SSE) a propósito para no competir con el stream
/// SSE de la pestaña Funcionalidad.
class CentinelStressTab extends StatefulWidget {
  const CentinelStressTab({
    required this.repository,
    required this.token,
    required this.tx,
    super.key,
  });

  final CentinelRepository repository;
  final String token;
  final String Function(String path, String fallback) tx;

  @override
  State<CentinelStressTab> createState() => _CentinelStressTabState();
}

class _CentinelStressTabState extends State<CentinelStressTab> {
  String _endpoint = 'RANDOM';
  final _customPathController = TextEditingController(text: '/api/');
  String _method = 'GET';
  double _users = 10;
  final _usersCustomController = TextEditingController(text: '1000');
  bool _fluctuate = false;
  int _duration = 30;
  int _rampUp = 0;
  double _timeout = 10;
  double _concurrency = 0;
  final _concurrencyCustomController = TextEditingController(text: '1000');
  bool _showRampupInfo = false;

  String _status = 'idle';
  bool _starting = false;
  Timer? _pollTimer;
  final List<Map<String, dynamic>> _ticks = [];
  List<Map<String, dynamic>> _errors = const [];
  Map<String, dynamic>? _result;
  int? _requestedUsers;
  int? _effectiveUsers;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void dispose() {
    _pollTimer?.cancel();
    _customPathController.dispose();
    _usersCustomController.dispose();
    _concurrencyCustomController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildConfig() {
    final path = _endpoint == 'custom'
        ? (_customPathController.text.trim().isEmpty
              ? '/api/auth/me'
              : _customPathController.text.trim())
        : _endpoint;
    var users = _users.round();
    if (_users >= 1000) {
      final custom = int.tryParse(_usersCustomController.text.trim());
      if (custom != null && custom > 1000) users = custom;
    }
    var concurrency = _concurrency.round();
    if (_concurrency >= 1000) {
      final custom = int.tryParse(_concurrencyCustomController.text.trim());
      if (custom != null) concurrency = custom;
    }
    return {
      'method': _endpoint == 'RANDOM' ? 'RANDOM' : _method,
      'path': path,
      'users': users,
      'duration': _duration,
      'ramp_up': _rampUp,
      'timeout': _timeout,
      'max_concurrency': concurrency,
      'fluctuate_users': _fluctuate,
    };
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _ticks.clear();
      _errors = const [];
      _result = null;
      _requestedUsers = null;
      _effectiveUsers = null;
    });
    try {
      await widget.repository.stressRun(widget.token, _buildConfig());
      if (!mounted) return;
      setState(() {
        _status = 'running';
        _starting = false;
      });
      _startPolling();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
      if (mounted) setState(() => _starting = false);
    } catch (_) {
      _showMessage(
        _tx('centinel.stress_start_error', 'No se pudo iniciar la prueba'),
        isError: true,
      );
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _abort() async {
    try {
      await widget.repository.stressAbort(widget.token);
    } catch (_) {
      // El siguiente poll ya reflejará el estado real.
    }
    _setIdle();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(milliseconds: 800),
      (_) => _poll(),
    );
    _poll();
  }

  Future<void> _poll() async {
    try {
      final data = await widget.repository.stressStatus(widget.token);
      if (!mounted) return;
      final ticks = (data['ticks'] as List?) ?? const [];
      final errors = (data['errors'] as List?) ?? const [];
      final status = (data['status'] ?? 'idle').toString();
      setState(() {
        if (ticks.length > _ticks.length) {
          _ticks.addAll(ticks.skip(_ticks.length).cast<Map<String, dynamic>>());
        }
        _errors = errors.cast<Map<String, dynamic>>();
        _requestedUsers = data['requested_users'] as int?;
        _effectiveUsers = data['effective_users'] as int?;
      });
      if (status == 'done' || status == 'error' || status == 'aborted') {
        final result = data['result'] as Map<String, dynamic>?;
        if (result != null && (result['total'] ?? 0) > 0) {
          setState(() => _result = result);
        }
        _setIdle();
      }
    } catch (_) {
      // Silencioso: el siguiente tick reintenta.
    }
  }

  void _setIdle() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (mounted) setState(() => _status = 'idle');
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

  Future<void> _exportCsv() async {
    final header = 'tick,count,errors,avg_s,p95_s,min_s,max_s,rps,active_users';
    final rows = _ticks.map((t) {
      return [
        t['tick'],
        t['count'],
        t['errors'],
        t['avg_s'],
        t['p95_s'],
        t['min_s'],
        t['max_s'],
        t['rps'],
        t['active_users'] ?? 0,
      ].join(',');
    });
    final csv = ([header, ...rows]).join('\n');
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 14);
    await FilePicker.saveFile(
      dialogTitle: _tx('centinel.summary_export_csv', 'Exportar CSV'),
      fileName: 'stress_$stamp.csv',
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildActionsBar(),
        const SizedBox(height: 12),
        _buildConfigCard(),
        if (_requestedUsers != null &&
            _effectiveUsers != null &&
            _effectiveUsers! < _requestedUsers!) ...[
          const SizedBox(height: 10),
          _capNotice(),
        ],
        const SizedBox(height: 12),
        _buildChartCard(),
        if (_result != null) ...[
          const SizedBox(height: 12),
          _buildSummaryCard(),
        ],
        if (_errors.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildErrorsCard(),
        ],
      ],
    );
  }

  Widget _buildActionsBar() {
    return Wrap(
      spacing: 8,
      children: [
        if (_status != 'running')
          PrimaryButton.icon(
            onPressed: _starting ? null : _start,
            icon: const Icon(Icons.play_arrow),
            label: Text(_tx('centinel.actions_stress_start', 'Iniciar prueba')),
          )
        else
          PrimaryButton.tonalIcon(
            onPressed: _abort,
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(_tx('centinel.actions_stress_stop', 'Detener')),
          ),
      ],
    );
  }

  Widget _pillGroup<T>({
    required List<(T, String)> options,
    required T value,
    required ValueChanged<T> onChanged,
  }) {
    return Wrap(
      spacing: 6,
      children: options.map((opt) {
        final selected = opt.$1 == value;
        return ChoiceChip(
          label: Text(opt.$2),
          selected: selected,
          onSelected: (_) => onChanged(opt.$1),
        );
      }).toList(),
    );
  }

  Widget _buildConfigCard() {
    final endpointOptions = [
      (
        'RANDOM',
        _tx('centinel.stress_endpoint_random', 'Random (endpoints mixtos)'),
      ),
      ..._predefinedEndpoints.map((e) => (e, e)),
      ('custom', _tx('centinel.stress_endpoint_custom', 'Personalizado…')),
    ];
    final disabled = _status == 'running';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tx('centinel.stress_endpoint_label', 'Endpoint'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: _endpoint,
                    isExpanded: true,
                    items: endpointOptions
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.$1,
                            child: Text(e.$2, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: disabled
                        ? null
                        : (v) => setState(() => _endpoint = v ?? 'RANDOM'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _endpoint == 'RANDOM' ? 'RANDOM' : _method,
                    items: const [
                      DropdownMenuItem(value: 'GET', child: Text('GET')),
                      DropdownMenuItem(value: 'POST', child: Text('POST')),
                      DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                      DropdownMenuItem(value: 'RANDOM', child: Text('Random')),
                    ],
                    onChanged: (disabled || _endpoint == 'RANDOM')
                        ? null
                        : (v) => setState(() => _method = v ?? 'GET'),
                  ),
                ),
              ],
            ),
            if (_endpoint == 'custom') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _customPathController,
                enabled: !disabled,
                decoration: const InputDecoration(hintText: '/api/...'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _tx('centinel.stress_users_label', 'Usuarios concurrentes'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _users,
                    min: 1,
                    max: 1000,
                    divisions: 999,
                    label: _users.round().toString(),
                    onChanged: disabled
                        ? null
                        : (v) => setState(() => _users = v),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _users.round().toString(),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (_users >= 1000)
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _usersCustomController,
                  enabled: !disabled,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'centinel.stress_custom_value_label',
                      'Valor personalizado (>1000)',
                    ),
                  ),
                ),
              ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _fluctuate,
              onChanged: disabled
                  ? null
                  : (v) => setState(() => _fluctuate = v ?? false),
              title: Text(
                _tx('centinel.stress_fluctuate_label', 'Fluctuar carga'),
              ),
              subtitle: Text(
                _tx(
                  'centinel.stress_fluctuate_hint',
                  'Introduce pausas aleatorias entre requests para simular usuarios reales',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _tx('centinel.stress_duration_label', 'Duración'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _pillGroup<int>(
              value: _duration,
              options: const [
                (10, '10s'),
                (30, '30s'),
                (60, '1min'),
                (300, '5min'),
              ],
              onChanged: disabled
                  ? (_) {}
                  : (v) => setState(() => _duration = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _tx('centinel.stress_rampup_label', 'Ramp-up'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                AppIconButton(
                  onPressed: () =>
                      setState(() => _showRampupInfo = !_showRampupInfo),
                  tooltip: _tx(
                    'centinel.stress_rampup_info',
                    'Qué es el ramp-up',
                  ),
                  icon: const Icon(Icons.info_outline, size: 16),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (_showRampupInfo)
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(
                    _tx(
                      'centinel.rampup_tooltip_body',
                      'El ramp-up es el tiempo que tarda en alcanzarse la carga máxima de usuarios: en vez de lanzarlos todos a la vez, los arranca de forma progresiva. P. ej. 100 usuarios con ramp-up de 10s arrancan uno cada 0,1s.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            _pillGroup<int>(
              value: _rampUp,
              options: [
                (0, _tx('centinel.stress_rampup_none', 'Ninguno')),
                (5, '5s'),
                (10, '10s'),
                (30, '30s'),
              ],
              onChanged: disabled ? (_) {} : (v) => setState(() => _rampUp = v),
            ),
            const SizedBox(height: 12),
            Text(
              _tx('centinel.stress_timeout_label', 'Timeout / req'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _pillGroup<double>(
              value: _timeout,
              options: const [
                (2.0, '2s'),
                (3.0, '3s'),
                (10.0, '10s'),
                (30.0, '30s'),
              ],
              onChanged: disabled
                  ? (_) {}
                  : (v) => setState(() => _timeout = v),
            ),
            const SizedBox(height: 12),
            Text(
              _tx('centinel.stress_concurrency_label', 'Concurrencia máx'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _concurrency,
                    min: 0,
                    max: 1000,
                    divisions: 1000,
                    label: _concurrency == 0
                        ? '∞'
                        : _concurrency.round().toString(),
                    onChanged: disabled
                        ? null
                        : (v) => setState(() => _concurrency = v),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    _concurrency == 0 ? '∞' : _concurrency.round().toString(),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (_concurrency >= 1000)
              SizedBox(
                width: 200,
                child: TextField(
                  controller: _concurrencyCustomController,
                  enabled: !disabled,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'centinel.stress_concurrency_custom_label',
                      'Valor personalizado (0 = sin límite)',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _capNotice() {
    final surface = Theme.of(context).colorScheme.surface;
    final iconColor = AppTheme.statusColor(Colors.orange, surface);
    return Card(
      color: Colors.orange.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tx(
                      'centinel.stress_cap_notice',
                      'Se pidieron {requested} usuarios pero el servidor limitó a {effective} por seguridad de hilos.',
                    )
                    .replaceAll('{requested}', '$_requestedUsers')
                    .replaceAll('{effective}', '$_effectiveUsers'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
