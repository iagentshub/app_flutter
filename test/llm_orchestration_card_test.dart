import 'package:app_flutter/features/workflows/cards/llm_orchestration_card.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:app_flutter/models/workflows/llm_orchestration_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _tx(String path, String fallback) => fallback;

void main() {
  for (final width in [360.0, 768.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('LLM orchestration card stays compact at ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const connections = {
        'router': ConnectionItem(
          raw: {'id': 'router', 'name': 'Router', 'model': 'router-model'},
        ),
        'first': ConnectionItem(
          raw: {'id': 'first', 'name': 'Fast', 'model': 'fast-model'},
        ),
        'second': ConnectionItem(
          raw: {'id': 'second', 'name': 'Smart', 'model': 'smart-model'},
        ),
      };
      const item = LlmOrchestrationItem(
        raw: {
          'id': 'route',
          'name': 'Enrutado profesional',
          'description': 'Selecciona la mejor conexión para cada tarea.',
          'mode': 'balanced',
          'router_connection_id': 'router',
          'candidates': [
            {'connection_id': 'first', 'routing_hint': 'Tareas rápidas'},
            {'connection_id': 'second', 'routing_hint': 'Trabajo complejo'},
          ],
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: LlmOrchestrationCard(
                item: item,
                connectionsById: connections,
                tx: _tx,
                onToggleActive: () {},
                onEdit: () {},
                onShare: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Enrutado profesional'), findsOneWidget);
      expect(find.text('Conexión orquestadora'), findsOneWidget);
      expect(find.text('Router · router-model'), findsOneWidget);
      expect(find.byType(Chip), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
