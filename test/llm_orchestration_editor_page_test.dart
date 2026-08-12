import 'package:app_flutter/features/workflows/pages/llm_orchestration_editor_page.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:app_flutter/models/workflows/llm_orchestration_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _connections = [
  ConnectionItem(raw: {'id': 'first', 'name': 'First', 'model': 'fast-model'}),
  ConnectionItem(
    raw: {'id': 'second', 'name': 'Second', 'model': 'smart-model'},
  ),
  ConnectionItem(
    raw: {'id': 'third', 'name': 'Third', 'model': 'router-model'},
  ),
];

String _tx(String path, String fallback) => fallback;

void main() {
  testWidgets('form switches between stack and balanced routing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LlmOrchestrationEditorPage(connections: _connections, tx: _tx),
      ),
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Pila'), findsOneWidget);
    expect(find.text('Balanceo'), findsOneWidget);
    expect(find.text('Instrucción de enrutado'), findsNWidgets(2));
    expect(find.text('Conexión orquestadora'), findsNothing);

    await tester.tap(find.text('Balanceo'));
    await tester.pumpAndSettle();

    expect(find.text('Conexión orquestadora'), findsOneWidget);
    expect(
      find.text(
        'Analiza la tarea y ordena las candidatas. Si falla, la orquestación se detiene.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('llm-orchestration-save')));
    await tester.pump();
    expect(find.text('Selecciona la conexión orquestadora'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('candidate list is reorderable and remains valid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(768, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: LlmOrchestrationEditorPage(connections: _connections, tx: _tx),
      ),
    );

    final handles = find.byIcon(Icons.drag_handle);
    expect(handles, findsNWidgets(2));
    await tester.drag(handles.first, const Offset(0, 180));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.drag_handle), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared orchestration maps private user connections', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const shared = LlmOrchestrationItem(
      raw: {
        'id': 'shared-route',
        'name': 'Shared route',
        'mode': 'stack',
        '_shared': true,
        '_binding_configured': false,
        'candidates': [
          {'connection_id': '', 'routing_hint': 'fast'},
          {'connection_id': '', 'routing_hint': 'complex'},
        ],
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: LlmOrchestrationEditorPage(
          connections: _connections,
          initial: shared,
          configureBinding: true,
          tx: _tx,
        ),
      ),
    );

    expect(find.text('Configurar mis conexiones'), findsOneWidget);
    expect(find.text('fast'), findsOneWidget);
    expect(find.text('complex'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
