import 'package:app_flutter/shared/widgets/animated_iagents_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpUntilVisible(
    WidgetTester tester,
    Finder finder, {
    int maxFrames = 20,
  }) async {
    for (var frame = 0; frame < maxFrames; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('No apareció la transición animada esperada');
  }

  testWidgets('repite logo, iA, Ai y logo en un bucle infinito', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AnimatedIAgentsMark())),
    );
    await tester.pump(const Duration(milliseconds: 475));
    expect(
      find.byKey(const Key('iagents-mark-animated-entrance')),
      findsOneWidget,
    );

    final logoToIa = find.byKey(const ValueKey('iagents-transition-logo-ia'));
    final iaToAi = find.byKey(const ValueKey('iagents-transition-ia-ai'));
    final aiToLogo = find.byKey(const ValueKey('iagents-transition-ai-logo'));

    await pumpUntilVisible(tester, logoToIa);
    expect(logoToIa, findsOneWidget);
    await pumpUntilVisible(tester, iaToAi);
    expect(iaToAi, findsOneWidget);
    await pumpUntilVisible(tester, aiToLogo);
    expect(aiToLogo, findsOneWidget);
    await pumpUntilVisible(tester, logoToIa);
    expect(logoToIa, findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('la versión animada respeta el movimiento reducido', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AnimatedIAgentsMark())),
    );

    expect(
      find.byKey(const Key('iagents-mark-animated-entrance')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('iagents-mark-animated-morph')),
      findsOneWidget,
    );
  });

  testWidgets('varios cargadores comparten el reloj de animación', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: IAgentsLoadingAnimationScope(
          child: Row(
            children: [
              Expanded(child: IAgentsLoadingMark()),
              Expanded(child: IAgentsLoadingMark()),
            ],
          ),
        ),
      ),
    );

    expect(
      find.byKey(const Key('iagents-loading-mark-morph')),
      findsNWidgets(2),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    expect(
      find.byKey(const Key('iagents-loading-mark-morph')),
      findsNWidgets(2),
    );
  });
}
