part of '../widgets/centinel_probe_tab.dart';

extension _CentinelProbeResults on _CentinelProbeTabState {
  Widget _buildChartCard() {
    final rps = _ticks.map((t) => (t['rps'] as num? ?? 0).toDouble()).toList();
    final avg = _ticks
        .map((t) => (t['avg_s'] as num? ?? 0).toDouble())
        .toList();
    final users = _ticks
        .map((t) => (t['users'] as num? ?? 0).toDouble())
        .toList();
    final errors = _ticks
        .map((t) => (t['errors'] as num? ?? 0).toDouble())
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tx('centinel.probe_chart_title', 'Evolución en tiempo real'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                _legendItem(
                  const Color(0xFF22C55E),
                  _tx('centinel.chart_legend_rps', 'req/s'),
                ),
                _legendItem(
                  const Color(0xFF6366F1),
                  _tx('centinel.probe_legend_avg', 'Avg s'),
                ),
                _legendItem(
                  const Color(0xFFF97316),
                  _tx('centinel.chart_legend_users', 'Usuarios'),
                ),
                _legendItem(
                  const Color(0xFFEF4444),
                  _tx('centinel.errors_table_col_error', 'Error'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: CentinelChart(
                emptyLabel: _tx(
                  'centinel.probe_chart_empty',
                  'Inicia la búsqueda para ver la gráfica',
                ),
                series: [
                  ChartSeries(values: rps, color: const Color(0xFF22C55E)),
                  ChartSeries(
                    values: avg,
                    color: const Color(0xFF6366F1),
                    ownScale: false,
                  ),
                  ChartSeries(values: users, color: const Color(0xFFF97316)),
                  ChartSeries(
                    values: errors,
                    color: const Color(0xFFEF4444),
                    style: ChartSeriesStyle.dots,
                  ),
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
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
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
    final errPct = errorRate is num
        ? (errorRate * 100).toStringAsFixed(1)
        : '?';
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
    final surface = Theme.of(context).colorScheme.surface;
    final textColor = AppTheme.statusColor(color, surface);
    return Card(
      color: color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
        ),
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
                  DataColumn(
                    label: Text(_tx('centinel.probe_col_users', 'Usuarios')),
                  ),
                  DataColumn(
                    label: Text(_tx('centinel.probe_col_rps', 'req/s')),
                  ),
                  DataColumn(
                    label: Text(_tx('centinel.summary_stat_errors', 'Errores')),
                  ),
                  DataColumn(
                    label: Text(_tx('centinel.probe_legend_avg', 'Avg s')),
                  ),
                  DataColumn(
                    label: Text(_tx('centinel.probe_col_status', 'Estado')),
                  ),
                ],
                rows: _steps.map((s) {
                  final status = (s['status'] ?? '').toString();
                  final total = s['total'] ?? 0;
                  final errors = s['errors'] ?? 0;
                  final errPct = (total is num && total > 0)
                      ? ((errors as num) / total * 100).toStringAsFixed(1)
                      : null;
                  final avgS = s['avg_s'];
                  Color statusColor;
                  String statusText;
                  switch (status) {
                    case 'ok':
                      statusColor = const Color(0xFF059669);
                      statusText =
                          '✓ ${_tx('centinel.probe_status_ok', 'Estable')}';
                    case 'fail':
                      statusColor = const Color(0xFFDC2626);
                      statusText =
                          '✗ ${_tx('centinel.probe_status_fail', 'Errores')}';
                    default:
                      statusColor = Colors.grey;
                      statusText = _tx(
                        'centinel.probe_status_running',
                        'Probando…',
                      );
                  }
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${s['users'] ?? '-'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(Text('${s['rps'] ?? '-'}')),
                      DataCell(
                        Text(
                          errors is num && errors > 0
                              ? '$errors (${errPct ?? '-'}%)'
                              : '0',
                        ),
                      ),
                      DataCell(
                        Text(avgS is num ? avgS.toStringAsFixed(3) : '-'),
                      ),
                      DataCell(
                        Text(
                          statusText,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
