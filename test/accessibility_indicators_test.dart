import 'package:app_flutter/features/profile/pages/profile_page.dart';
import 'package:app_flutter/shared/state/brand_icon_controller.dart';
import 'package:app_flutter/shared/widgets/status_dot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'StatusDot expone su estado y no parpadea con movimiento reducido',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: StatusDot(
            state: StatusDotState.pending,
            semanticLabel: 'Actualizando',
          ),
        ),
      );

      expect(
        tester.getSemantics(find.byType(StatusDot)),
        matchesSemantics(label: 'Actualizando', isLiveRegion: true),
      );
      expect(
        find.descendant(
          of: find.byType(StatusDot),
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('la opción de icono anuncia nombre y selección', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIconChoice(
          variant: BrandIconVariant.coordinatorWhiteOnRed,
          label: 'Coordinador blanco sobre rojo',
          selected: true,
          onSelected: (_) {},
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(BrandIconChoice)),
      matchesSemantics(
        label: 'Coordinador blanco sobre rojo',
        hasSelectedState: true,
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
  });
}
