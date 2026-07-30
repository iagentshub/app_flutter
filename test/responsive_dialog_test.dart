import 'package:app_flutter/shared/widgets/responsive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('limita los diálogos al umbral mínimo de escritorio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(dialogContentWidth(context, 760), 672);
            expect(dialogContentHeight(context, 520), 480);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });

  testWidgets('nunca produce dimensiones negativas en viewports extremos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(40, 80);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            expect(dialogContentWidth(context, 760), 0);
            expect(dialogContentHeight(context, 520), 0);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  });
}
