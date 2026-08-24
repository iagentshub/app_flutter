import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../branding/brand_mark_geometry.dart';

/// Versión estática del icono original de iAgents Hub.
class StaticIAgentsMark extends StatelessWidget {
  const StaticIAgentsMark({this.size = 124, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'iAgents',
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              size * BrandMarkGeometry.tileCornerRadius,
            ),
            boxShadow: const [
              BoxShadow(
                color: FncColors.overlayMaroon40,
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              size * BrandMarkGeometry.tileCornerRadius,
            ),
            child: const ColoredBox(
              color: FncColors.red,
              child: CustomPaint(
                key: Key('iagents-mark-static'),
                painter: StaticIAgentsMarkPainter(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StaticIAgentsMarkPainter extends CustomPainter {
  const StaticIAgentsMarkPainter();

  Path _cubicPath(Size size, BrandCubic curve) {
    Offset point(BrandPoint value) =>
        Offset(value.x * size.width, value.y * size.height);

    final start = point(curve.start);
    final control1 = point(curve.control1);
    final control2 = point(curve.control2);
    final end = point(curve.end);
    return Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        control1.dx,
        control1.dy,
        control2.dx,
        control2.dy,
        end.dx,
        end.dy,
      );
  }

  Path _linePath(Size size, BrandLine line) {
    return Path()
      ..moveTo(line.start.x * size.width, line.start.y * size.height)
      ..lineTo(line.end.x * size.width, line.end.y * size.height);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = FncColors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * BrandMarkGeometry.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawPath(_cubicPath(size, BrandMarkGeometry.coordinatorLeft), stroke)
      ..drawPath(_cubicPath(size, BrandMarkGeometry.coordinatorRight), stroke)
      ..drawPath(_linePath(size, BrandMarkGeometry.coordinatorStem), stroke)
      ..drawPath(
        _linePath(size, BrandMarkGeometry.coordinatorConnector),
        stroke,
      )
      ..drawCircle(
        Offset(
          BrandMarkGeometry.coordinatorDot.x * size.width,
          BrandMarkGeometry.coordinatorDot.y * size.height,
        ),
        BrandMarkGeometry.coordinatorDotRadius * size.shortestSide,
        Paint()..color = FncColors.white,
      );
  }

  @override
  bool shouldRepaint(StaticIAgentsMarkPainter oldDelegate) => false;
}
