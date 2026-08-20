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
              _tx('centinel.probe_chart_title'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                _legendItem(
                  FncColors.chartGreen,
                  _tx('centinel.chart_legend_rps'),
                ),
                _legendItem(
                  FncColors.chartIndigo,
                  _tx('centinel.probe_legend_avg'),
                ),
                _legendItem(
                  FncColors.chartOrange,
                  _tx('centinel.chart_legend_users'),
                ),
                _legendItem(
                  FncColors.chartRed,
                  _tx('centinel.errors_table_col_error'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 240,
              child: CentinelChart(
                emptyLabel: _tx('centinel.probe_chart_empty'),
                series: [
                  ChartSeries(values: rps, color: FncColors.chartGreen),
                  ChartSeries(
                    values: avg,
                    color: FncColors.chartIndigo,
                    ownScale: false,
                  ),
                  ChartSeries(values: users, color: FncColors.chartOrange),
                  ChartSeries(
                    values: errors,
                    color: FncColors.chartRed,
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
        Text(label, style: const TextStyle(fontSize: FncFonts.size11)),
      ],
    );
  }

  Widget _buildVerdict() {
    final v = _verdict;
    if (_finalStatus == 'aborted') {
      final stable = v?['stable_users'];
      return _verdictBanner(
        FncColors.materialOrange,
        '⚠️ ${_tx('centinel.probe_stopped_manually')}${stable != null ? ' ${_tx('centinel.probe_last_stable').replaceAll('{n}', '$stable')}' : ''}',
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
        FncColors.materialGreen,
        '✅ ${_tx('centinel.probe_no_errors_until').replaceAll('{n}', '${stableUsers ?? '?'}')} ${_tx('centinel.probe_increase_step_hint')}',
      );
    }
    if (stableUsers == null) {
      return _verdictBanner(
        FncColors.materialRed,
        '❌ ${_tx('centinel.probe_first_failure_at').replaceAll('{n}', '$breakUsers')}'
        '${breakTotal != null ? ' · ${_tx('centinel.probe_concurrent_requests').replaceAll('{n}', '$breakTotal')}' : ''}'
        ' · ${_tx('centinel.probe_error_percent').replaceAll('{pct}', errPct)}',
      );
    }
    return _verdictBanner(
      FncColors.materialOrange,
      '✅ ${_tx('centinel.probe_stable_until').replaceAll('{n}', '$stableUsers')} → '
      '❌ ${_tx('centinel.probe_first_failure_at').replaceAll('{n}', '$breakUsers')}'
      '${breakTotal != null ? ' · ${_tx('centinel.probe_concurrent_requests').replaceAll('{n}', '$breakTotal')}' : ''}'
      ' · ${_tx('centinel.probe_error_percent').replaceAll('{pct}', errPct)}',
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
                  DataColumn(label: Text(_tx('centinel.probe_col_users'))),
                  DataColumn(label: Text(_tx('centinel.probe_col_rps'))),
                  DataColumn(label: Text(_tx('centinel.summary_stat_errors'))),
                  DataColumn(label: Text(_tx('centinel.probe_legend_avg'))),
                  DataColumn(label: Text(_tx('centinel.probe_col_status'))),
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
                      statusColor = FncColors.success;
                      statusText = '✓ ${_tx('centinel.probe_status_ok')}';
                    case 'fail':
                      statusColor = FncColors.danger;
                      statusText = '✗ ${_tx('centinel.probe_status_fail')}';
                    default:
                      statusColor = FncColors.materialGrey;
                      statusText = _tx('centinel.probe_status_running');
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
