import 'package:app_flutter/shared/navigation/shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cierra un editor imperativo y conserva la sección base', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MaterialApp(
        home: Navigator(
          key: navigatorKey,
          pages: const [
            MaterialPage<void>(child: Scaffold(body: Text('Sección base'))),
          ],
          onDidRemovePage: (page) {},
        ),
      ),
    );

    navigatorKey.currentState!.push<void>(
      MaterialPageRoute(
        builder: (context) => const Scaffold(body: Text('Editor abierto')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Editor abierto'), findsOneWidget);

    closeShellOverlays(navigatorKey.currentState!);
    await tester.pumpAndSettle();

    expect(find.text('Editor abierto'), findsNothing);
    expect(find.text('Sección base'), findsOneWidget);
  });
}
