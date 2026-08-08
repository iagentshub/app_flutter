import 'package:app_flutter/shared/branding/brand_mark_geometry.dart';
import 'package:app_flutter/shared/widgets/launch_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('la secuencia de splash es siempre logo, iA, Ai y logo', () {
    expect(splashSequence, const [
      SplashMark.logo,
      SplashMark.ia,
      SplashMark.ai,
      SplashMark.logo,
    ]);
  });

  test('iA y Ai conservan la lectura internacional de la marca', () {
    expect(BrandMarkGeometry.iaDot.x, lessThan(0.5));
    expect(BrandMarkGeometry.iaStem.start.x, lessThan(0.5));
    expect(BrandMarkGeometry.iaLeft.end.x, greaterThan(0.5));
    expect(BrandMarkGeometry.iaConnector.end.x, greaterThan(0.5));

    expect(BrandMarkGeometry.aiDot.x, greaterThan(0.5));
    expect(BrandMarkGeometry.aiStem.start.x, greaterThan(0.5));
    expect(BrandMarkGeometry.aiRight.end.x, lessThan(0.5));
    expect(BrandMarkGeometry.aiConnector.start.x, lessThan(0.5));
  });

  Future<void> pumpMark(
    WidgetTester tester,
    double progress, {
    SplashMark fromMark = SplashMark.logo,
    SplashMark toMark = SplashMark.ia,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CoordinatorToIaMark(
            animation: AlwaysStoppedAnimation<double>(progress),
            fromMark: fromMark,
            toMark: toMark,
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

  CoordinatorToIaPainter morphPainter(WidgetTester tester) {
    final customPaint = tester.widget<CustomPaint>(
      find.byKey(const Key('splash-icon-morph')),
    );
    return customPaint.painter! as CoordinatorToIaPainter;
  }

  testWidgets('progress cero siempre representa el coordinator', (
    tester,
  ) async {
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

  testWidgets('pasa directamente de iA a Ai sin volver al logo', (
    tester,
  ) async {
    await pumpMark(tester, 0, fromMark: SplashMark.ia, toMark: SplashMark.ai);
    expect(morphProgress(tester), 0);
    expect(morphPainter(tester).fromMark, SplashMark.ia);
    expect(morphPainter(tester).toMark, SplashMark.ai);

    await pumpMark(tester, 0.5, fromMark: SplashMark.ia, toMark: SplashMark.ai);
    expect(morphProgress(tester), greaterThan(0));
    expect(morphProgress(tester), lessThan(1));

    await pumpMark(tester, 1, fromMark: SplashMark.ia, toMark: SplashMark.ai);
    expect(morphProgress(tester), 1);
  });

  testWidgets('la última transición termina siempre en el logo', (
    tester,
  ) async {
    await pumpMark(tester, 1, fromMark: SplashMark.ai, toMark: SplashMark.logo);

    expect(morphProgress(tester), 1);
    expect(morphPainter(tester).toMark, SplashMark.logo);
  });
}
