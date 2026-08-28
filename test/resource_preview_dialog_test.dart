import 'package:app_flutter/shared/widgets/resource_preview_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_de_prueba.dart';

/// La vista previa del catálogo volcaba el payload como JSON con sangría —el
/// mismo diálogo en Explorar y en el perfil público—. La abre quien decide si
/// quiere el recurso, que no es quien lo programó: `"use_memory": true` no le
/// dice nada.
void main() {
  setUp(cargarTraduccionesDePrueba);

  Future<void> abrir(WidgetTester tester, Map<String, dynamic> payload) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showResourcePreviewDialog(
                context: context,
                payload: payload,
                title: payload['name'] as String? ?? '',
                typeLabel: 'Agentes',
                stars: 7,
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('un agente se explica en palabras, no en JSON', (tester) async {
    await abrir(tester, {
      'resource_type': 'agent',
      'name': 'Analista financiero',
      'description': 'Revisa cuentas y resume desviaciones.',
      'owner_username': 'grace',
      'labels': ['public', 'official'],
      'skills': ['Resumir', 'Comparar'],
      'tools': ['Calculadora'],
      'prompts': <String>[],
      'knowledge': <String>[],
      'use_memory': true,
      'temperature': 0.2,
      'system_prompt': 'Eres un analista meticuloso.',
    });

    expect(find.text('Analista financiero'), findsOneWidget);
    expect(find.text('Revisa cuentas y resume desviaciones.'), findsOneWidget);
    expect(find.textContaining('7 estrellas'), findsOneWidget);

    // Los recuentos van delante porque son lo que se compara entre recursos,
    // y el singular tiene su propia palabra: «1 herramientas» no lo dice nadie.
    expect(find.textContaining('2 habilidades'), findsOneWidget);
    expect(find.textContaining('Resumir · Comparar'), findsOneWidget);
    expect(find.textContaining('1 herramienta:'), findsOneWidget);
    // Lo que está vacío no ocupa una fila diciendo que está vacío.
    expect(find.textContaining('plantilla'), findsNothing);

    // El comportamiento, dicho como se comporta.
    expect(
      find.textContaining('recuerda conversaciones anteriores'),
      findsOneWidget,
    );
    expect(find.textContaining('preciso y literal'), findsOneWidget);

    // Y nada de sintaxis de JSON en pantalla.
    expect(find.textContaining('"use_memory"'), findsNothing);
    expect(find.textContaining('{'), findsNothing);
  });

  testWidgets('las instrucciones del agente llegan plegadas', (tester) async {
    await abrir(tester, {
      'resource_type': 'agent',
      'name': 'Analista financiero',
      'description': '',
      'labels': <String>[],
      'use_memory': false,
      'temperature': 0.9,
      'system_prompt': 'Eres un analista meticuloso.',
    });

    expect(find.text('Instrucciones del agente'), findsOneWidget);
    expect(find.text('Eres un analista meticuloso.'), findsNothing);

    await tester.tap(find.text('Instrucciones del agente'));
    await tester.pumpAndSettle();
    expect(find.text('Eres un analista meticuloso.'), findsOneWidget);
  });

  testWidgets('un documento enseña formato, origen y extensión', (
    tester,
  ) async {
    await abrir(tester, {
      'resource_type': 'knowledge',
      'name': 'Manual de compras',
      'description': 'Procedimiento interno.',
      'labels': <String>[],
      'type': 'pdf',
      'source': 'manual-compras.pdf',
      'char_count': 12400,
      'content': 'Capítulo 1…',
    });

    expect(find.textContaining('PDF'), findsOneWidget);
    expect(find.textContaining('manual-compras.pdf'), findsOneWidget);
    // El número se lee de un vistazo: 12400 caracteres son 12.400.
    expect(find.textContaining('12.400 caracteres'), findsOneWidget);
  });

  testWidgets('un workflow enumera sus pasos en orden', (tester) async {
    await abrir(tester, {
      'resource_type': 'workflow',
      'name': 'Cierre mensual',
      'description': '',
      'labels': <String>[],
      'steps': 3,
      'agent_names': ['Extractor', 'Analista', 'Redactor'],
    });

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Extractor'), findsOneWidget);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Redactor'), findsOneWidget);
  });

  testWidgets('sin descripción lo dice, en vez de dejar el hueco', (
    tester,
  ) async {
    await abrir(tester, {
      'resource_type': 'prompt',
      'name': 'Resumen ejecutivo',
      'description': '',
      'labels': <String>[],
      'alias': 'resumen',
      'content': 'Resume el texto en cinco puntos.',
    });

    expect(find.text('Este recurso no trae descripción.'), findsOneWidget);
    expect(find.textContaining('@resumen'), findsOneWidget);
  });
}
