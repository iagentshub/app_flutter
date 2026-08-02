import 'package:app_flutter/shared/widgets/arc_gauge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza sin overflow para 0%, valores intermedios y 100%', (
    tester,
  ) async {
    for (final progress in [0.0, 0.42, 1.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ArcGauge(
                progress: progress,
                color: Colors.blue,
                child: Text('${(progress * 100).round()}%'),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(ArcGauge), findsOneWidget);
    }
  });

  testWidgets('recorta valores fuera de rango sin lanzar excepciones', (
    tester,
  ) async {
    for (final progress in [-0.5, 1.8]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ArcGauge(progress: progress, color: Colors.red),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('respeta el tamaño solicitado', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ArcGauge(progress: 0.5, color: Colors.green, size: 80),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(ArcGauge));
    expect(size, const Size(80, 80));
  });
}
