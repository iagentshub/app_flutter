import 'package:app_flutter/features/agents/cards/agent_card.dart';
import 'package:app_flutter/features/connections/cards/connection_card.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:app_flutter/models/knowledge/knowledge_models.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_de_prueba.dart';

Widget _host(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: SizedBox(width: 900, child: child)),
    ),
  );
}

void main() {
  setUp(cargarTraduccionesDePrueba);

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
          tx: tr,
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
          tx: tr,
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

  testWidgets('AgentCard muestra Enlace sin acciones de gestión', (
    tester,
  ) async {
    const item = AgentItem(
      raw: {
        'id': 'agent-link',
        'name': 'Referencia',
        'labels': ['private', 'linked'],
      },
    );

    await tester.pumpWidget(
      _host(
        AgentCard(
          item: item,
          tx: tr,
          onChat: () {},
          onExport: (_) {},
          onShare: () {},
          onHistory: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('Enlace'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsNothing);

    await tester.tap(find.byTooltip('Más acciones'));
    await tester.pumpAndSettle();
    expect(find.text('Compartir con grupo'), findsNothing);
    expect(find.text('Eliminar'), findsNothing);
  });

  testWidgets('AgentCard muestra Fork como copia editable', (tester) async {
    const item = AgentItem(
      raw: {
        'id': 'agent-fork',
        'name': 'Copia',
        'labels': ['private', 'fork'],
      },
    );

    await tester.pumpWidget(
      _host(
        AgentCard(
          item: item,
          tx: tr,
          onChat: () {},
          onExport: (_) {},
          onShare: () {},
          onHistory: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );

    expect(find.text('Fork'), findsOneWidget);
    expect(find.byTooltip('Editar'), findsOneWidget);
  });

  testWidgets('AgentCard incluye los packs vinculados en su grafo', (
    tester,
  ) async {
    const item = AgentItem(
      raw: {
        'id': 'agent-pack',
        'name': 'Agente con pack',
        'knowledge_packs': ['pack-1'],
      },
    );

    await tester.pumpWidget(
      _host(
        AgentCard(
          item: item,
          knowledgePackNames: const {'pack-1': 'Scripts de producción'},
          knowledgePackItems: const {
            'pack-1': [
              KnowledgeItem(
                raw: {
                  'id': 'file-1',
                  'name': 'deploy.sh',
                  'pack_id': 'pack-1',
                  'pack_relative_path': 'ops/deploy.sh',
                },
              ),
            ],
          },
          tx: tr,
          onChat: () {},
          onExport: (_) {},
          onShare: () {},
          onHistory: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.byTooltip('Ver grafo de contenido'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Scripts de producción'), findsOneWidget);
    // El pack enseña su jerarquía real —carpeta y fichero— igual que ya hacía
    // el grafo servido por el backend. Antes esta card pintaba la ruta
    // relativa entera como etiqueta de un nodo plano.
    expect(find.text('ops'), findsOneWidget);
    expect(find.text('deploy.sh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
