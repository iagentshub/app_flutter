import 'package:app_flutter/features/workflows/models/workflow_step_draft.dart';
import 'package:app_flutter/features/workflows/widgets/workflow_visual_canvas.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vyuh_node_flow/vyuh_node_flow.dart';

Finder _portFinder(String nodeId, String portId) => find.byWidgetPredicate(
  (widget) =>
      widget is PortWidget &&
      widget.nodeId == nodeId &&
      widget.port.id == portId,
);

Offset _connectionPoint(WidgetTester tester, String nodeId, String portId) {
  final portWidget = tester.widget<PortWidget>(_portFinder(nodeId, portId));
  final node = portWidget.controller.getNode(nodeId)!;
  return node.getConnectionPoint(
    portId,
    portSize: portWidget.theme.resolveSize(portWidget.port),
  );
}

Widget _testCanvas({
  required List<WorkflowStepDraft> steps,
  void Function(String, Offset)? onStepMoved,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 620,
        child: WorkflowVisualCanvas(
          steps: steps,
          agents: const [
            AgentItem(raw: {'id': 'agent-1', 'name': 'Recepcionista'}),
            AgentItem(raw: {'id': 'agent-2', 'name': 'Especialista'}),
          ],
          selectedStepId: steps.first.id,
          onStepSelected: (_) {},
          onStepMoved: onStepMoved ?? (_, _) {},
          onStepDeleted: (_) {},
          onConnectionCreated: (_, _, _) {},
          onConnectionDeleted: (_, _, _) {},
          canCreateConnection: (_, _) => true,
          fitTooltip: 'Encajar',
          zoomInTooltip: 'Acercar',
          zoomOutTooltip: 'Alejar',
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
  );
}

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

    await tester.pumpWidget(_testCanvas(steps: [first, second]));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('workflow-node-step-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('workflow-node-step-2')), findsOneWidget);
    expect(find.text('Recibir solicitud'), findsOneWidget);
    expect(find.text('Resolver solicitud'), findsOneWidget);
    expect(first.positionX, isNotNull);
    expect(second.positionY, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ancla cada conexión al borde correcto de su nodo', (
    tester,
  ) async {
    final first = WorkflowStepDraft(
      id: 'step-1',
      agentId: 'agent-1',
      label: 'Origen',
      positionX: 80,
      positionY: 80,
      nextStepIds: ['step-2'],
    );
    final second = WorkflowStepDraft(
      id: 'step-2',
      agentId: 'agent-2',
      label: 'Destino',
      positionX: 390,
      positionY: 80,
    );

    await tester.pumpWidget(_testCanvas(steps: [first, second]));
    await tester.pump(const Duration(milliseconds: 300));

    final sourceRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-step-1')),
    );
    final targetRect = tester.getRect(
      find.byKey(const ValueKey('workflow-node-step-2')),
    );
    final outputRect = tester.getRect(_portFinder('step-1', 'output'));
    final inputRect = tester.getRect(_portFinder('step-2', 'input'));

    expect(outputRect.right, closeTo(sourceRect.right, 3));
    expect(outputRect.center.dy, closeTo(sourceRect.center.dy, 3));
    expect(inputRect.left, closeTo(targetRect.left, 3));
    expect(inputRect.center.dy, closeTo(targetRect.center.dy, 3));

    final outputWidget = tester.widget<PortWidget>(
      _portFinder('step-1', 'output'),
    );
    final sourceNode = outputWidget.controller.getNode('step-1')!;
    final sourcePoint = _connectionPoint(tester, 'step-1', 'output');
    expect(
      sourcePoint,
      sourceNode.visualPosition.value +
          Offset(sourceNode.size.value.width, sourceNode.size.value.height / 2),
    );

    final inputWidget = tester.widget<PortWidget>(
      _portFinder('step-2', 'input'),
    );
    final targetNode = inputWidget.controller.getNode('step-2')!;
    final targetPoint = _connectionPoint(tester, 'step-2', 'input');
    expect(
      targetPoint,
      targetNode.visualPosition.value +
          Offset(0, targetNode.size.value.height / 2),
    );
  });

  testWidgets('mantiene los puertos alineados al arrastrar un nodo', (
    tester,
  ) async {
    final first = WorkflowStepDraft(
      id: 'step-1',
      agentId: 'agent-1',
      label: 'Origen',
      positionX: 80,
      positionY: 80,
      nextStepIds: ['step-2'],
    );
    final second = WorkflowStepDraft(
      id: 'step-2',
      agentId: 'agent-2',
      label: 'Destino',
      positionX: 390,
      positionY: 80,
    );
    Offset? savedPosition;

    await tester.pumpWidget(
      _testCanvas(
        steps: [first, second],
        onStepMoved: (id, position) {
          if (id == first.id) {
            savedPosition = position;
            first.positionX = position.dx;
            first.positionY = position.dy;
          }
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final nodeFinder = find.byKey(const ValueKey('workflow-node-step-1'));
    final beforeNode = tester.getRect(nodeFinder);
    final dragPort = tester.widget<PortWidget<WorkflowStepDraft>>(
      _portFinder('step-1', 'output'),
    );
    dragPort.controller.snap?.enabled = true;
    dragPort.controller.startNodeDrag('step-1');
    dragPort.controller.moveNodeDrag(const Offset(90, 70));
    dragPort.controller.endNodeDrag();
    await tester.pumpAndSettle();

    final afterNode = tester.getRect(nodeFinder);
    final outputRect = tester.getRect(_portFinder('step-1', 'output'));
    expect(afterNode.topLeft, isNot(beforeNode.topLeft));
    expect(outputRect.right, closeTo(afterNode.right, 3));
    expect(outputRect.center.dy, closeTo(afterNode.center.dy, 3));
    final outputWidget = tester.widget<PortWidget<WorkflowStepDraft>>(
      _portFinder('step-1', 'output'),
    );
    final movedNode = outputWidget.controller.getNode('step-1')!;
    expect(
      _connectionPoint(tester, 'step-1', 'output'),
      movedNode.visualPosition.value +
          Offset(movedNode.size.value.width, movedNode.size.value.height / 2),
    );
    expect(savedPosition, isNotNull);
    expect(savedPosition, isNot(const Offset(80, 80)));
    expect(movedNode.position.value, movedNode.visualPosition.value);
    expect(savedPosition, movedNode.visualPosition.value);
    expect(Offset(first.positionX!, first.positionY!), savedPosition);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserva la conexión interactiva al sincronizar el formulario', (
    tester,
  ) async {
    final first = WorkflowStepDraft(
      id: 'step-1',
      agentId: 'agent-1',
      label: 'Origen',
    );
    final second = WorkflowStepDraft(
      id: 'step-2',
      agentId: 'agent-2',
      label: 'Destino',
    );
    final steps = [first, second];

    await tester.pumpWidget(_testCanvas(steps: steps));
    await tester.pump(const Duration(milliseconds: 300));
    final portWidget = tester.widget<PortWidget<WorkflowStepDraft>>(
      _portFinder('step-1', 'output'),
    );
    final controller =
        portWidget.controller as NodeFlowController<WorkflowStepDraft, String>;
    controller.addConnection(
      Connection<String>(
        id: 'interactive-connection',
        sourceNodeId: 'step-1',
        sourcePortId: 'output',
        targetNodeId: 'step-2',
        targetPortId: 'input',
      ),
    );
    first.nextStepIds.add('step-2');

    await tester.pumpWidget(_testCanvas(steps: steps));
    await tester.pump();

    expect(controller.connections, hasLength(1));
    expect(controller.connections.single.id, 'interactive-connection');
    expect(tester.takeException(), isNull);
  });
}
