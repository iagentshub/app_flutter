import 'package:app_flutter/features/workflows/models/workflow_step_draft.dart';
import 'package:app_flutter/features/workflows/widgets/workflow_visual_canvas.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renderiza nodos y conexiones sin desbordar el lienzo', (
    tester,
  ) async {
    final first = WorkflowStepDraft(
      id: 'step-1',
      agentId: 'agent-1',
      label: 'Recibir solicitud',
      nextStepIds: ['step-2'],
    );
    final second = WorkflowStepDraft(
      id: 'step-2',
      agentId: 'agent-2',
      label: 'Resolver solicitud',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 620,
            child: WorkflowVisualCanvas(
              steps: [first, second],
              agents: const [
                AgentItem(raw: {'id': 'agent-1', 'name': 'Recepcionista'}),
                AgentItem(raw: {'id': 'agent-2', 'name': 'Especialista'}),
              ],
              selectedStepId: first.id,
              onStepSelected: (_) {},
              onStepMoved: (_, _) {},
              onStepDeleted: (_) {},
              onConnectionCreated: (_, _, _) {},
              onConnectionDeleted: (_, _, _) {},
              canCreateConnection: (_, _) => true,
              fitTooltip: 'Encajar',
              zoomInTooltip: 'Acercar',
              zoomOutTooltip: 'Alejar',
              connectionHint: 'Conecta los nodos',
              inputLabel: 'Entrada',
              outputLabel: 'Salida',
              missingAgentLabel: 'Sin agente',
              agentKindLabel: 'Agente',
              evaluatorKindLabel: 'Evaluador',
              loopLabel: 'Bucle',
              invalidConnectionMessage: 'Conexión no permitida',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('workflow-node-step-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('workflow-node-step-2')), findsOneWidget);
    expect(find.text('Recibir solicitud'), findsOneWidget);
    expect(find.text('Resolver solicitud'), findsOneWidget);
    expect(first.positionX, isNotNull);
    expect(second.positionY, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
