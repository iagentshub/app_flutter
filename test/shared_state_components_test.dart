import 'package:app_flutter/shared/widgets/animated_iagents_mark.dart';
import 'package:app_flutter/shared/widgets/async_state_panel.dart';
import 'package:app_flutter/shared/widgets/confirm_action_dialog.dart';
import 'package:app_flutter/shared/widgets/resource_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AsyncStatePanel presenta carga, error y reintento', (
    tester,
  ) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncStatePanel.error(
            title: 'No se pudo cargar',
            message: 'Error de red',
            retryLabel: 'Reintentar',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('No se pudo cargar'), findsOneWidget);
    expect(find.text('Error de red'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    expect(retried, isTrue);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AsyncStatePanel.loading())),
    );
    expect(find.byType(IAgentsLoadingMark), findsOneWidget);
  });

  testWidgets('showConfirmActionDialog devuelve la decisión', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (value) {
            context = value;
            return const SizedBox();
          },
        ),
      ),
    );

    final result = showConfirmActionDialog(
      context,
      title: 'Eliminar',
      message: '¿Continuar?',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Confirmar',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    expect(await result, isTrue);
  });

  testWidgets('ResourceToolbar conserva búsqueda, acciones y resumen', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResourceToolbar(
            search: TextField(),
            actions: [Text('Crear'), Text('Actualizar')],
            summary: Text('3 elementos'),
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Crear'), findsOneWidget);
    expect(find.text('Actualizar'), findsOneWidget);
    expect(find.text('3 elementos'), findsOneWidget);
  });
}
