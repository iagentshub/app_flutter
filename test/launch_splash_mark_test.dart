import 'package:app_flutter/shared/branding/brand_mark_geometry.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/widgets/launch_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets(
    'muestra el coordinator estático cuando el sistema desactiva animaciones',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final backendController = await BackendController.bootstrap();
      var finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LaunchSplash(
            backendController: backendController,
            onFinished: () => finished = true,
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(
        find.byKey(const Key('splash-icon-morph')),
      );
      final painter = customPaint.painter! as CoordinatorToIaPainter;
      expect(painter.fromMark, SplashMark.logo);
      expect(painter.toMark, SplashMark.logo);
      expect(painter.progress, 0);

      await tester.pump(
        reducedMotionSplashDuration - const Duration(milliseconds: 1),
      );
      expect(finished, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(finished, isTrue);
    },
  );

  testWidgets(
    'mantiene la entrada animada cuando las animaciones están activas',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures();
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      final backendController = await BackendController.bootstrap();
      var finished = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LaunchSplash(
            backendController: backendController,
            onFinished: () => finished = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 475));

      final customPaint = tester.widget<CustomPaint>(
        find.byKey(const Key('splash-icon-entrance')),
      );
      final painter = customPaint.painter! as MarkEntrancePainter;
      expect(painter.progress, greaterThan(0));
      expect(painter.progress, lessThan(1));
      expect(finished, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

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
