import 'package:app_flutter/shared/widgets/buttons/app_buttons.dart';
import 'package:app_flutter/shared/widgets/confirm_action_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// El diálogo pintaba siempre el botón de confirmar como acción principal, con
/// el color de marca: nada distinguía «Guardar» de «Eliminar para siempre» en
/// las 19 llamadas que confirman un borrado, y se confirmaba por inercia.
void main() {
  /// Deja el diálogo abierto y devuelve un lector del resultado, que solo se
  /// conoce cuando el usuario cierra.
  Future<bool? Function()> abrir(
    WidgetTester tester, {
    required bool destructive,
  }) async {
    bool? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                resultado = await showConfirmActionDialog(
                  context,
                  title: 'Eliminar agente',
                  message: '¿Seguro que quieres eliminar «Agente de soporte»?',
                  cancelLabel: 'Cancelar',
                  confirmLabel: 'Eliminar',
                  destructive: destructive,
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return () => resultado;
  }

  testWidgets('una confirmación destructiva usa el botón de peligro', (
    tester,
  ) async {
    await abrir(tester, destructive: true);

    expect(find.byType(DangerButton), findsOneWidget);
    expect(find.byType(PrimaryButton), findsNothing);
    // El aviso de la cabecera acompaña al color.
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('una confirmación normal mantiene el botón principal', (
    tester,
  ) async {
    await abrir(tester, destructive: false);

    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.byType(DangerButton), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('en un diálogo destructivo, Enter cancela', (tester) async {
    final leerResultado = await abrir(tester, destructive: true);

    // El foco arranca en «Cancelar», así que pulsar Enter sobre el diálogo
    // recién abierto no borra nada. Mismo criterio que GitHub y macOS.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Eliminar agente'), findsNothing, reason: 'se cerró');
    expect(leerResultado(), isFalse, reason: 'y se cerró cancelando');
  });

  testWidgets('el botón de peligro sí confirma al pulsarlo', (tester) async {
    final leerResultado = await abrir(tester, destructive: true);

    await tester.tap(find.text('Eliminar'));
    await tester.pumpAndSettle();

    expect(leerResultado(), isTrue);
  });
}
