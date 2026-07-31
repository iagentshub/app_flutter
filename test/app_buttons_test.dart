import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_flutter/shared/widgets/buttons/app_buttons.dart';

void main() {
  testWidgets('los botones semánticos delegan sus acciones', (tester) async {
    var primaryPressed = false;
    var secondaryPressed = false;
    var tertiaryPressed = false;
    var iconPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PrimaryButton(
                onPressed: () => primaryPressed = true,
                child: const Text('Principal'),
              ),
              SecondaryButton.icon(
                onPressed: () => secondaryPressed = true,
                icon: const Icon(Icons.add),
                label: const Text('Secundario'),
              ),
              TertiaryButton(
                onPressed: () => tertiaryPressed = true,
                child: const Text('Terciario'),
              ),
              AppIconButton(
                tooltip: 'Acción',
                icon: const Icon(Icons.settings),
                onPressed: () => iconPressed = true,
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('Principal'));
    await tester.tap(find.text('Secundario'));
    await tester.tap(find.text('Terciario'));
    await tester.tap(find.byTooltip('Acción'));

    expect(primaryPressed, isTrue);
    expect(secondaryPressed, isTrue);
    expect(tertiaryPressed, isTrue);
    expect(iconPressed, isTrue);
  });

  testWidgets('un botón sin callback permanece deshabilitado', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrimaryButton(onPressed: null, child: Text('Deshabilitado')),
        ),
      ),
    );

    final materialButton = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(materialButton.onPressed, isNull);
  });

  testWidgets('preserva las variantes visuales Material', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PrimaryButton.elevated(
                onPressed: () {},
                child: const Text('Elevado'),
              ),
              PrimaryButton.tonalIcon(
                onPressed: () {},
                icon: const Icon(Icons.science),
                label: const Text('Tonal'),
              ),
              AppIconButton.filled(
                onPressed: () {},
                icon: const Icon(Icons.add),
              ),
              AppIconButton.filledTonal(
                onPressed: () {},
                icon: const Icon(Icons.stop),
              ),
              AppIconButton.outlined(
                onPressed: () {},
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.text('Tonal'), findsOneWidget);
    expect(find.byType(IconButton), findsNWidgets(3));
  });
}
