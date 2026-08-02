import 'dart:async';

import 'package:app_flutter/features/workflows/dialogs/run_progress_dialog.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _definition = {
  'nodes': [
    {'id': 'a', 'agent_id': 'ag-1', 'label': 'Analista', 'kind': 'agent'},
    {'id': 'b', 'agent_id': 'ag-2', 'label': 'Redactor', 'kind': 'agent'},
  ],
  'edges': [
    {'source': 'a', 'target': 'b', 'type': 'sequence'},
  ],
};

String _tx(String path, String fallback) => fallback;

/// Monta el visor como lo hace la app: dentro de un `showDialog`, para que se
/// dimensione contra la pantalla y no contra una caja artificial.
Future<void> _open(
  WidgetTester tester,
  Stream<Map<String, dynamic>> stream,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              barrierDismissible: false,
              builder: (context) => RunProgressDialog(
                workflowName: 'Informe semanal',
                definition: _definition,
                agents: const [
                  AgentItem(raw: {'id': 'ag-1', 'name': 'Analista'}),
                  AgentItem(raw: {'id': 'ag-2', 'name': 'Redactor'}),
                ],
                stream: stream,
                tx: _tx,
              ),
            ),
            child: const Text('abrir'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    // El visor es una vista ancha; con los 800x600 por defecto el panel de
    // detalle queda tan corto que su ListView ni construye los elementos.
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.physicalSize = const Size(1600, 1000);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('pinta el grafo y refleja el avance de la ejecución', (
    tester,
  ) async {
    final controller = StreamController<Map<String, dynamic>>();
    await _open(tester, controller.stream);

    // El run se muestra sobre el grafo, no como lista plana.
    expect(find.byKey(const ValueKey('workflow-node-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('workflow-node-b')), findsOneWidget);
    expect(find.text('0/2 pasos'), findsOneWidget);
    expect(find.text('Cancelar ejecución'), findsOneWidget);

    controller.add({
      'type': 'stage_started',
      'node_id': 'a',
      'agent_name': 'Analista',
      'iteration': 1,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    controller.add({
      'type': 'stage_done',
      'node_id': 'a',
      'agent_name': 'Analista',
      'output': 'Datos recopilados',
      'iteration': 1,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('1/2 pasos'), findsOneWidget);
    // El panel de detalle sigue al nodo activo y muestra su salida.
    expect(find.text('Datos recopilados'), findsOneWidget);
    expect(find.text('Completado'), findsOneWidget);

    controller.add({'type': 'workflow_done', 'output': 'Informe listo'});
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Terminado: ya no se ofrece cancelar.
    expect(find.text('Cancelar ejecución'), findsNothing);
    expect(find.text('Cerrar'), findsOneWidget);

    await controller.close();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra el motivo del evaluador que rechaza', (tester) async {
    final controller = StreamController<Map<String, dynamic>>();
    await _open(tester, controller.stream);

    controller.add({'type': 'evaluation_started', 'node_id': 'b'});
    controller.add({
      'type': 'evaluation_done',
      'node_id': 'b',
      'approved': false,
      'reason': 'Falta la sección de riesgos',
      'iteration': 1,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // El backend ya mandaba `reason`; antes se descartaba sin mostrarlo.
    expect(find.text('Rechazado: repite el ciclo'), findsOneWidget);
    expect(find.text('Falta la sección de riesgos'), findsOneWidget);

    await controller.close();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
