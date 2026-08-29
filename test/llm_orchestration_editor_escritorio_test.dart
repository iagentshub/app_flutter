import 'package:app_flutter/features/workflows/pages/llm_orchestration_editor_page.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El editor de orquestación LLM se veía como una app de móvil estirada.
///
/// Era una sola columna topada a 900 px y centrada: en una ventana de 1920
/// quedaban ~510 px de vacío a cada lado y todos los campos en una pila única,
/// con cada candidata ocupando dos filas porque sus dos campos —un desplegable
/// y una frase corta— se apilaban.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget montar() => MaterialApp(
    home: LlmOrchestrationEditorPage(
      connections: const [
        ConnectionItem(raw: {'id': 'c1', 'name': 'Uno', 'model': 'm1'}),
        ConnectionItem(raw: {'id': 'c2', 'name': 'Dos', 'model': 'm2'}),
        ConnectionItem(raw: {'id': 'c3', 'name': 'Tres', 'model': 'm3'}),
      ],
      tx: (clave) => clave,
    ),
  );

  testWidgets('en escritorio reparte configuración y candidatas en dos columnas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    // La configuración va en su columna de ancho fijo, y las candidatas en la
    // que se queda con el resto: si vuelve a ser una pila única, no hay Row.
    final columnaFija = find.byWidgetPredicate(
      (w) => w is SizedBox && w.width == 480,
    );
    expect(columnaFija, findsOneWidget);

    // Y el formulario deja de estar topado al ancho de lectura de 900.
    final ancho = tester.getSize(find.byType(Form)).width;
    expect(ancho, greaterThan(900));
  });

  testWidgets('por debajo del corte se conserva la columna única', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(montar());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byWidgetPredicate((w) => w is SizedBox && w.width == 480),
      findsNothing,
    );
  });
}
