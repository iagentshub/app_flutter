import 'package:app_flutter/shared/widgets/launch_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpMark(WidgetTester tester, double progress) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoordinatorToIaMark(
            animation: AlwaysStoppedAnimation<double>(progress),
          ),
        ),
      ),
    );
  }

  double morphProgress(WidgetTester tester) {
    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const Key('splash-icon-morph')),
    );
    return (customPaint.painter! as CoordinatorToIaPainter).progress;
  }

  testWidgets('empieza con el coordinador y termina con iA', (tester) async {
    await pumpMark(tester, 0);

    expect(morphProgress(tester), 0);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Opacity), findsNothing);

    await pumpMark(tester, 1);

    expect(morphProgress(tester), 1);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('interpola la geometría durante la transformación', (
    tester,
  ) async {
    await pumpMark(tester, 0.5);

    expect(morphProgress(tester), greaterThan(0));
    expect(morphProgress(tester), lessThan(1));
  });
}
