import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../repositories/centinel_repository.dart';
import 'centinel_chart.dart';

part '../centinel/probe_results.dart';

/// Pestaña "Buscar límite" de Centinel: sube la carga paso a paso hasta el
/// primer error, para encontrar el techo estable de la plataforma — igual
/// para la sección de búsqueda de límites de Centinel.
class CentinelProbeTab extends StatefulWidget {
  const CentinelProbeTab({
    required this.repository,
    required this.token,
    required this.tx,
    super.key,
  });

  final CentinelRepository repository;
  final String token;
  final String Function(String path, String fallback) tx;

  @override
  State<CentinelProbeTab> createState() => _CentinelProbeTabState();
}

class _CentinelProbeTabState extends State<CentinelProbeTab>
    with StateMessaging {
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
      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 1200),
        (_) => _poll(),
      );
      unawaited(_poll());
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
      if (mounted) setState(() => _starting = false);
    } catch (_) {
      showMessage(
        _tx('centinel.probe_start_error', 'No se pudo iniciar la búsqueda'),
        isError: true,
      );
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          children: [
            if (!_running)
              PrimaryButton.icon(
                onPressed: _starting ? null : _start,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  _tx('centinel.actions_probe_start', 'Iniciar búsqueda'),
                ),
              )
            else
              PrimaryButton.tonalIcon(
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
                    decoration: InputDecoration(
                      labelText: _tx('centinel.probe_start_label', 'Inicio'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _stepController,
                    enabled: !disabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _tx('centinel.probe_step_label', 'Paso'),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _concurrencyController,
                    enabled: !disabled,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _tx(
                        'centinel.probe_concurrency_label',
                        'Concurrencia máx (0=∞)',
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _timeoutController,
                    enabled: !disabled,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: _tx(
                        'centinel.probe_timeout_label',
                        'Timeout/req (s)',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _tx('centinel.probe_duration_step_label', 'Duración por paso'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [(10, '10s'), (30, '30s'), (60, '1min')].map((opt) {
                return ChoiceChip(
                  label: Text(opt.$2),
                  selected: _duration == opt.$1,
                  onSelected: disabled
                      ? null
                      : (_) => setState(() => _duration = opt.$1),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            Text(
              _tx(
                'centinel.probe_hint',
                'Lanza pruebas secuenciales aumentando el número de usuarios de paso en paso. Se detiene al primer error, mostrando el límite estable de la plataforma.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
