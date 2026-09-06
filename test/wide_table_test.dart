import 'package:app_flutter/shared/widgets/wide_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('una tabla más ancha que la ventana lleva una sola barra', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        // En escritorio el tema añade su propia barra a cada scrollable; el
        // test corre como Windows para comprobar que no salen dos.
        theme: ThemeData(platform: TargetPlatform.windows),
        home: const Scaffold(
          body: WideTable(child: SizedBox(width: 1200, height: 40)),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byWidgetPredicate((w) => w is RawScrollbar), findsOneWidget);

    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.controller!.position.maxScrollExtent, 800);
  });
}
