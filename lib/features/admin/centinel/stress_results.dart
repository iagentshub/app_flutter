part of '../widgets/centinel_stress_tab.dart';

extension _CentinelStressResults on _CentinelStressTabState {
  Widget _buildChartCard() {
    final avg = _ticks
        .map((t) => (t['avg_s'] as num? ?? 0).toDouble())
        .toList();
    final p95 = _ticks
        .map((t) => (t['p95_s'] as num? ?? 0).toDouble())
        .toList();
    final users = _ticks
        .map((t) => (t['active_users'] as num? ?? 0).toDouble())
        .toList();
    final rps = _ticks.map((t) => (t['rps'] as num? ?? 0).toDouble()).toList();

    // Media acumulada ponderada por nº peticiones ANTES de cada tick, para
    // colorear cada tramo de "avg" en verde (mejor) o rojo (peor).
    var cumWeightedSum = 0.0, cumCount = 0.0;
    final avgColors = <Color>[];
    var breakIndex = -1;
    for (var i = 0; i < _ticks.length; i++) {
      final t = _ticks[i];
      final count = (t['count'] as num? ?? 0).toDouble();
      final baseline = cumCount > 0 ? (cumWeightedSum / cumCount) : avg[i];
      cumWeightedSum += avg[i] * count;
      cumCount += count;
      avgColors.add(
        avg[i] > baseline ? const Color(0xFFDC2626) : const Color(0xFF059669),
      );
      if (breakIndex < 0 && count > 0) {
        final errRate = (t['errors'] as num? ?? 0) / count;
        if (errRate > 0.05) breakIndex = i;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _tx(
                      'centinel.chart_response_time_title',
                      'Tiempo de respuesta en tiempo real',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_ticks.isNotEmpty)
                  TertiaryButton.icon(
                    onPressed: _exportCsv,
                    icon: const Icon(Icons.download_outlined, size: 16),
                    label: Text(
                      _tx('centinel.summary_export_csv', 'Exportar CSV'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              children: [
                _legendItem(
                  const Color(0xFF059669),
                  _tx('centinel.chart_legend_avg', 'Promedio'),
                ),
                _legendItem(
                  const Color(0xFF3987E5),
                  _tx('centinel.chart_legend_p95', 'p95'),
                ),
                _legendItem(
                  const Color(0xFF9085E9),
                  _tx('centinel.chart_legend_rps', 'req/s'),
                ),
                _legendItem(
                  const Color(0xFFD55181),
                  _tx('centinel.chart_legend_users', 'Usuarios'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 260,
              child: CentinelChart(
                emptyLabel: _tx(
                  'centinel.stress_chart_empty',
                  'Inicia la prueba para ver la gráfica',
                ),
                markerIndex: breakIndex >= 0 ? breakIndex : null,
                markerLabel: breakIndex >= 0
                    ? _tx('centinel.chart_break_marker', 'quiebre')
                    : null,
                series: [
                  ChartSeries(
                    values: rps,
                    color: const Color(0xFF9085E9),
                    style: ChartSeriesStyle.bars,
                  ),
                  ChartSeries(
                    values: p95,
                    color: const Color(0xFF3987E5),
                    ownScale: false,
                  ),
                  ChartSeries(
                    values: users,
                    color: const Color(0xFFD55181),
                    style: ChartSeriesStyle.dashedLine,
                  ),
                  ChartSeries(
                    values: avg,
                    color: const Color(0xFF059669),
                    perPointColors: avgColors,
                    ownScale: false,
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

  Widget _buildSummaryCard() {
    final result = _result!;
    final total = result['total'] ?? 0;
    final errors = result['errors'] ?? 0;
    final errorPct = (total is num && total > 0)
        ? ((errors as num) / total * 100).toStringAsFixed(1)
        : '0.0';
    final avgS = result['avg_s'] ?? 0;
    final avgPerUserS = result['avg_per_user_s'] ?? 0;
    final muchWorse =
        avgS is num &&
        avgPerUserS is num &&
        avgS > 0 &&
        avgPerUserS > avgS * 1.15;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tx('centinel.results_title', 'Resultados'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _statBlock(
                  _tx('centinel.summary_stat_total', 'Peticiones totales'),
                  '$total',
                ),
                _statBlock(
                  _tx('centinel.summary_stat_errors', 'Errores'),
                  '$errors ($errorPct%)',
                  color: (errors is num && errors > 0) ? Colors.red : null,
                ),
                _statBlock(
                  _tx('centinel.summary_stat_avg', 'Media de resolución'),
                  '${avgS}s',
                ),
                _statBlock(
                  _tx('centinel.summary_stat_avg_user', 'Media por usuario'),
                  '${avgPerUserS}s',
                  color: muchWorse ? Colors.red : null,
                ),
              ],
            ),
            if (_errors.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTop3(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statBlock(String label, String value, {Color? color}) {
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTop3() {
    final endpointCounts = <String, int>{};
    final msgCounts = <String, int>{};
    for (final e in _errors) {
      final method = (e['method'] ?? 'GET').toString();
      final path = (e['path'] ?? '?').toString();
      final key = '$method $path';
      endpointCounts[key] = (endpointCounts[key] ?? 0) + 1;

      final status = e['status'];
      var msg = status != null
          ? 'HTTP $status'
          : (e['msg'] ?? 'Error').toString().split(':').first.trim();
      msgCounts[msg] = (msgCounts[msg] ?? 0) + 1;
    }
    final total = _errors.length;
    final topEndpoints = endpointCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMsgs = msgCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _top3Column(
            _tx('centinel.summary_top_endpoints', 'Top endpoints con fallos'),
            topEndpoints.take(3),
            total,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _top3Column(
            _tx('centinel.summary_top_error_types', 'Top tipos de error'),
            topMsgs.take(3),
            total,
          ),
        ),
      ],
    );
  }

  Widget _top3Column(
    String title,
    Iterable<MapEntry<String, int>> entries,
    int total,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        ...entries.toList().asMap().entries.map((e) {
          final pct = total > 0
              ? (e.value.value / total * 100).toStringAsFixed(1)
              : '0.0';
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Text(
                  '${e.key + 1}.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    e.value.key,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('$pct%', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildErrorsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _tx('centinel.errors_table_title', 'Errores detectados'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                _summaryChip('${_errors.length}'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 260,
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('t (s)')),
                      DataColumn(
                        label: Text(
                          _tx('centinel.errors_table_col_method', 'Método'),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          _tx('centinel.errors_table_col_endpoint', 'Endpoint'),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          _tx('centinel.errors_table_col_code', 'Código'),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          _tx('centinel.errors_table_col_error', 'Error'),
                        ),
                      ),
                      const DataColumn(label: Text('s')),
                    ],
                    rows: _errors.map((e) {
                      return DataRow(
                        cells: [
                          DataCell(Text('${e['t'] ?? '-'}')),
                          DataCell(Text('${e['method'] ?? '-'}')),
                          DataCell(Text('${e['path'] ?? '-'}')),
                          DataCell(Text('${e['status'] ?? '-'}')),
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: Text(
                                '${e['msg'] ?? '-'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text('${e['s'] ?? '-'}')),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
