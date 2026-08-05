import 'package:app_flutter/features/agents/cards/agent_card.dart';
import 'package:app_flutter/features/connections/cards/connection_card.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _tx(String path, String fallback) => fallback;

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 900, child: child)),
    ),
  );
}

void main() {
  testWidgets('AgentCard renders data and delegates its edit action', (
    tester,
  ) async {
    var edited = false;
    const item = AgentItem(
      raw: {
        'id': 'agent-1',
        'name': 'Coordinator',
        'agent_type': 'orchestrator',
        'model': 'model-1',
        'connection_id': 'connection-1',
        'description': 'Coordinates tasks',
        'labels': ['production'],
      },
    );

    await tester.pumpWidget(
      _host(
        AgentCard(
          item: item,
          tx: _tx,
          onChat: () {},
          onExport: (_) {},
          onShare: () {},
          onHistory: () {},
          onEdit: () => edited = true,
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('Coordinator'), findsOneWidget);
    expect(find.text('orchestrator · model-1 · connection-1'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar'));
    expect(edited, isTrue);
  });

  testWidgets('ConnectionCard disables unavailable virtual actions', (
    tester,
  ) async {
    var tested = false;
    const item = ConnectionItem(
      raw: {
        'id': 'shared::connection-1',
        'name': 'Shared NVIDIA',
        'type': 'nvidia',
        'model': 'model-1',
      },
    );

    await tester.pumpWidget(
      _host(
        ConnectionCard(
          item: item,
          tx: _tx,
          providerLabel: 'Test provider',
          onTest: () => tested = true,
          onShare: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );

    final testButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Test'),
    );
    expect(testButton.onPressed, isNull);
    expect(tested, isFalse);
    expect(find.text('Virtual'), findsOneWidget);
  });
}
