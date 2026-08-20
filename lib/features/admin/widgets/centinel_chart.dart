import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../utils/i18n.dart';

enum ChartSeriesStyle { line, dashedLine, bars, dots }

/// Una serie de la gráfica en vivo de Centinel (stress/probe). `ownScale`
/// decide si se normaliza a su propio máximo (p. ej. usuarios, req/s) o si
/// comparte el eje principal etiquetado en segundos (p. ej. media/p95).
class ChartSeries {
  const ChartSeries({
    required this.values,
    required this.color,
    this.style = ChartSeriesStyle.line,
    this.perPointColors,
    this.ownScale = true,
  });

  final List<double> values;
  final Color color;
  final ChartSeriesStyle style;
  final List<Color>? perPointColors;
  final bool ownScale;
}

/// Gráfica de líneas en vivo (avg/p95/usuarios/rps de Centinel), portada del
/// Gráfico de estrés con un eje
/// principal etiquetado en segundos compartido por las series de latencia, y
/// el resto de series normalizadas a su propio máximo sin etiquetar (su
/// significado va en la leyenda, no en el eje).
class CentinelChart extends StatelessWidget {
  const CentinelChart({
    required this.series,
    this.markerIndex,
    this.markerLabel,
    this.emptyLabel,
    super.key,
  });

  final List<ChartSeries> series;
  final int? markerIndex;
  final String? markerLabel;

  /// Texto del vacío. Sin él, el genérico traducido.
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) {
    final hasData = series.any((s) => s.values.isNotEmpty);
    if (!hasData) {
      return Center(
        child: Text(
          emptyLabel ?? tr('admin.centinel_chart_empty'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return CustomPaint(
      size: Size.infinite,
      painter: _ChartPainter(
        series: series,
        markerIndex: markerIndex,
        markerLabel: markerLabel,
        gridColor: scheme.outlineVariant,
        textColor: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.series,
    required this.markerIndex,
    required this.markerLabel,
    required this.gridColor,
    required this.textColor,
  });

  final List<ChartSeries> series;
  final int? markerIndex;
  final String? markerLabel;
  final Color gridColor;
  final Color textColor;

  static const _padLeft = 44.0;
  static const _padRight = 12.0;
  static const _padTop = 12.0;
  static const _padBottom = 22.0;

  @override
  void paint(Canvas canvas, Size size) {
    final chartW = size.width - _padLeft - _padRight;
    final chartH = size.height - _padTop - _padBottom;
    if (chartW <= 0 || chartH <= 0) return;

    final n = series
        .map((s) => s.values.length)
        .fold(0, (a, b) => a > b ? a : b);
    if (n == 0) return;

    final primary = series.where((s) => !s.ownScale).toList();
    var primaryMax = 0.001;
    for (final s in primary) {
      for (final v in s.values) {
        if (v > primaryMax) primaryMax = v;
      }
    }

    double xAt(int i) => _padLeft + (n <= 1 ? 0 : (i / (n - 1)) * chartW);

    // Grid horizontal + etiquetas del eje principal (segundos).
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final textStyle = TextStyle(color: textColor, fontSize: FncFonts.size10);
    const gridLines = 4;
    for (var i = 0; i <= gridLines; i++) {
      final y = _padTop + (chartH / gridLines) * i;
      _drawDashedLine(
        canvas,
        Offset(_padLeft, y),
        Offset(_padLeft + chartW, y),
        gridPaint,
      );
      final value = primaryMax * (1 - i / gridLines);
      final tp = TextPainter(
        text: TextSpan(text: '${value.toStringAsFixed(2)}s', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(_padLeft - tp.width - 6, y - tp.height / 2));
    }

    // Eje X (índice de tick ~ segundos transcurridos).
    final step = (n / 6).ceil().clamp(1, n);
    for (var j = 0; j < n; j += step) {
      final tp = TextPainter(
        text: TextSpan(text: '${j}s', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(xAt(j) - tp.width / 2, size.height - _padBottom + 6),
      );
    }

    // Series: primero barras (fondo), luego líneas, luego puntos.
    for (final s in series.where((s) => s.style == ChartSeriesStyle.bars)) {
      _drawBars(canvas, s, chartH, xAt);
    }
    for (final s in series.where(
      (s) =>
          s.style == ChartSeriesStyle.line ||
          s.style == ChartSeriesStyle.dashedLine,
    )) {
      _drawLine(
        canvas,
        s,
        chartH,
        xAt,
        dashed: s.style == ChartSeriesStyle.dashedLine,
        ownMax: primaryMax,
      );
    }
    for (final s in series.where((s) => s.style == ChartSeriesStyle.dots)) {
      _drawDots(canvas, s, chartH, xAt);
    }

    // Marcador vertical (p. ej. "quiebre" del test).
    final marker = markerIndex;
    if (marker != null && marker >= 0 && marker < n) {
      final x = xAt(marker);
      final markerPaint = Paint()
        ..color = FncColors.materialRed.withValues(alpha: 0.7)
        ..strokeWidth = 1.5;
      _drawDashedLine(
        canvas,
        Offset(x, _padTop),
        Offset(x, _padTop + chartH),
        markerPaint,
      );
      if (markerLabel != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: markerLabel,
            style: const TextStyle(
              color: FncColors.materialRed,
              fontSize: FncFonts.size9,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x + 3, _padTop));
      }
    }
  }

  double _ownMax(List<double> values) {
    var max = 0.001;
    for (final v in values) {
      if (v > max) max = v;
    }
    return max;
  }

  void _drawBars(
    Canvas canvas,
    ChartSeries s,
    double chartH,
    double Function(int) xAt,
  ) {
    final max = _ownMax(s.values);
    final paint = Paint()..color = s.color.withValues(alpha: 0.16);
    for (var i = 0; i < s.values.length; i++) {
      final barH = chartH * (s.values[i] / max);
      final x = xAt(i);
      canvas.drawRect(
        Rect.fromLTWH(x - 2, _padTop + chartH - barH, 4, barH),
        paint,
      );
    }
  }

  void _drawLine(
    Canvas canvas,
    ChartSeries s,
    double chartH,
    double Function(int) xAt, {
    required bool dashed,
    required double ownMax,
  }) {
    final max = s.ownScale ? _ownMax(s.values) : ownMax;
    Offset pointAt(int i) =>
        Offset(xAt(i), _padTop + chartH - chartH * (s.values[i] / max));

    if (s.perPointColors != null) {
      final paint = Paint()..strokeWidth = 1.6;
      for (var i = 1; i < s.values.length; i++) {
        paint.color = s.perPointColors![i];
        canvas.drawLine(pointAt(i - 1), pointAt(i), paint);
      }
      return;
    }

    final paint = Paint()
      ..color = s.color
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    if (!dashed) {
      final path = Path();
      for (var i = 0; i < s.values.length; i++) {
        final p = pointAt(i);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, paint);
    } else {
      for (var i = 1; i < s.values.length; i++) {
        _drawDashedLine(
          canvas,
          pointAt(i - 1),
          pointAt(i),
          paint,
          dashWidth: 3,
          gapWidth: 2,
        );
      }
    }
  }

  void _drawDots(
    Canvas canvas,
    ChartSeries s,
    double chartH,
    double Function(int) xAt,
  ) {
    final paint = Paint()..color = s.color;
    for (var i = 0; i < s.values.length; i++) {
      if (s.values[i] <= 0) continue;
      canvas.drawCircle(Offset(xAt(i), _padTop + 6), 2.6, paint);
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint, {
    double dashWidth = 3,
    double gapWidth = 3,
  }) {
    final total = (to - from).distance;
    if (total == 0) return;
    final direction = (to - from) / total;
    var covered = 0.0;
    var draw = true;
    var current = from;
    while (covered < total) {
      final segment = draw ? dashWidth : gapWidth;
      final next = current + direction * segment;
      if (draw) canvas.drawLine(current, next, paint);
      current = next;
      covered += segment;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    // `series` es una lista nueva en cada build (los tabs la reconstruyen
    // aunque solo cambie, p. ej., un slider ajeno a la gráfica), así que
    // comparar por referencia repintaría siempre; comparamos el contenido
    // real para saltarnos el repintado cuando los datos no han cambiado.
    if (oldDelegate.markerIndex != markerIndex) return true;
    if (oldDelegate.series.length != series.length) return true;
    for (var i = 0; i < series.length; i++) {
      final a = oldDelegate.series[i];
      final b = series[i];
      if (a.color != b.color ||
          a.style != b.style ||
          a.ownScale != b.ownScale) {
        return true;
      }
      if (!listEquals(a.values, b.values)) return true;
      if (!listEquals(a.perPointColors, b.perPointColors)) return true;
    }
    return false;
  }
}
