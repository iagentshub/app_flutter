import 'package:app_flutter/app/theme/app_theme.dart';
import 'package:app_flutter/features/agents/widgets/agent_compact_tile.dart';
import 'package:app_flutter/features/agents/widgets/agent_list_order.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:app_flutter/shared/widgets/buttons/app_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sorting leaves source pagination order intact and breaks ties by id',
    () {
      final source = [
        const AgentItem(raw: {'id': 'z', 'name': 'Zulu', 'tokens_in': 1}),
        const AgentItem(raw: {'id': 'b', 'name': 'Alpha', 'tokens_in': 10}),
        const AgentItem(raw: {'id': 'a', 'name': 'alpha', 'tokens_out': 20}),
      ];
      expect(orderAgents(source, AgentListOrder.name).map((a) => a.id), [
        'a',
        'b',
        'z',
      ]);
      expect(
        orderAgents(source, AgentListOrder.nameDescending).map((a) => a.id),
        ['z', 'a', 'b'],
      );
      expect(orderAgents(source, AgentListOrder.usage).map((a) => a.id), [
        'a',
        'b',
        'z',
      ]);
      expect(source.map((a) => a.id), ['z', 'b', 'a']);
    },
  );

  testWidgets('busy buttons keep their size and block duplicate submission', (
    tester,
  ) async {
    var busy = false;
    var calls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return PrimaryButton.icon(
                busy: busy,
                busyLabel: 'Processing',
                onPressed: () => calls++,
                icon: const Icon(Icons.save),
                label: const Text('Save changes'),
              );
            },
          ),
        ),
      ),
    );
    final before = tester.getSize(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    update(() => busy = true);
    await tester.pump();
    expect(tester.getSize(find.byType(FilledButton)), before);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    expect(calls, 1);
    update(() => busy = false);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'compact rows reveal original actions at narrow widths and large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 900);
      addTearDown(tester.view.reset);
      var edited = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Scaffold(
              body: ListView(
                children: [
                  AgentCompactTile(
                    item: const AgentItem(
                      raw: {
                        'id': 'a',
                        'name': 'Support agent',
                        'model': 'Model',
                      },
                    ),
                    chatLabel: 'Chat',
                    inactiveLabel: 'Inactive',
                    onChat: null,
                    details: TextButton(
                      onPressed: () => edited = true,
                      child: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(find.text('Edit'), findsNothing);
      await tester.tap(find.text('Support agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      expect(edited, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test('keyboard focus is distinct from hover in both themes', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final style = theme.outlinedButtonTheme.style!;
      final hovered = style.side!.resolve({WidgetState.hovered})!;
      final focused = style.side!.resolve({WidgetState.focused})!;
      expect(hovered.color, isNot(focused.color));
      expect(focused.width, 2);
      expect(style.overlayColor!.resolve({WidgetState.disabled}), isNull);
    }
  });
}
