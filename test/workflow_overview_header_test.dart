import 'package:app_flutter/features/workflows/widgets/workflow_overview_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(double width, VoidCallback onCreate) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: WorkflowOverviewHeader(
            createLabel: 'Crear workflow',
            onCreate: onCreate,
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final width in [360.0, 920.0]) {
    testWidgets('se adapta a ${width.toInt()} px sin overflow', (tester) async {
      var created = false;
      await tester.pumpWidget(_host(width, () => created = true));

      expect(find.text('Crear workflow'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Crear workflow'));
      expect(created, isTrue);
    });
  }
}
