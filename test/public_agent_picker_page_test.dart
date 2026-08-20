import 'package:app_flutter/features/agents/pages/public_agent_picker_page.dart';
import 'package:app_flutter/models/explore/explore_models.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_de_prueba.dart';

void main() {
  setUp(cargarTraduccionesDePrueba);

  testWidgets('usa una página propia, busca y selecciona a 360 px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const agents = [
      ExploreItem(
        raw: {
          'resource_id': 'support',
          'name': 'Soporte profesional',
          'description': 'Atiende consultas de clientes',
        },
      ),
      ExploreItem(
        raw: {
          'resource_id': 'sales',
          'name': 'Ventas',
          'description': 'Cualifica oportunidades',
        },
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: PublicAgentPickerPage(agents: agents, tx: tr),
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('public-agent-search')),
      'soporte',
    );
    await tester.pump();

    expect(find.text('Soporte profesional'), findsOneWidget);
    expect(find.text('Ventas'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
