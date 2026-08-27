import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/widgets/launch_splash.dart';
import 'package:app_flutter/shared/widgets/static_iagents_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('mantiene estático el icono original de iAgentsHub', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final backendController = await BackendController.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: LaunchSplash(
          backendController: backendController,
          onFinished: () {},
        ),
      ),
    );

    expect(find.byType(StaticIAgentsMark), findsOneWidget);
    expect(find.byKey(const Key('iagents-mark-static')), findsOneWidget);
    expect(
      find.byKey(const Key('iagents-mark-animated-entrance')),
      findsNothing,
    );
    expect(find.byKey(const Key('iagents-mark-animated-morph')), findsNothing);

    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const Key('iagents-mark-static')), findsOneWidget);
    expect(find.byKey(const Key('iagents-mark-animated-morph')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sitúa la animación de Datakreo entre el centro y el pie', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final backendController = await BackendController.bootstrap();

    await tester.pumpWidget(
      MaterialApp(
        home: LaunchSplash(
          backendController: backendController,
          onFinished: () {},
        ),
      ),
    );

    final position = tester.widget<Align>(
      find.byKey(const Key('dakreo-signature-position')),
    );
    expect(position.alignment, const Alignment(0, 0.58));

    await tester.pump(const Duration(milliseconds: 550));
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('dakreo-signature-opacity')))
          .opacity,
      greaterThan(0),
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('dakreo-mark-opacity')))
          .opacity,
      greaterThan(0),
    );
    expect(
      tester
          .widget<Align>(find.byKey(const Key('dakreo-word-reveal')))
          .widthFactor,
      inExclusiveRange(0, 1),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('muestra el estado final cuando desactiva animaciones', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
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

    expect(find.byKey(const Key('iagents-mark-static')), findsOneWidget);
    expect(find.text('By'), findsOneWidget);
    expect(find.text('DATAKREO'), findsOneWidget);
    expect(find.bySemanticsLabel('By Datakreo'), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('dakreo-mark-opacity')))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('dakreo-cursor-opacity')))
          .opacity,
      0,
    );
    expect(
      tester
          .widget<Align>(find.byKey(const Key('dakreo-word-reveal')))
          .widthFactor,
      1,
    );

    await tester.pump(
      reducedMotionSplashDuration - const Duration(milliseconds: 1),
    );
    expect(finished, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(finished, isTrue);
  });
}
