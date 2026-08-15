import 'dart:typed_data';

import 'package:app_flutter/features/knowledge/dialogs/knowledge_pack_dialog.dart';
import 'package:app_flutter/features/knowledge/models/local_knowledge_file.dart';
import 'package:app_flutter/shared/widgets/multi_select_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('clasifica documentos, código e imágenes sin incluir secretos', () {
    expect(isSupportedKnowledgePackPath('docs/README.md'), isTrue);
    expect(isSupportedKnowledgePackPath('scripts/deploy.py'), isTrue);
    expect(isSupportedKnowledgePackPath('skills/SKILL.md'), isTrue);
    expect(isSupportedKnowledgePackPath('photos/diagram.png'), isTrue);
    expect(isSupportedKnowledgePackPath('photos/large-image.jpg'), isTrue);
    expect(isSupportedKnowledgePackPath('photos/capture.heic'), isTrue);
    expect(isSupportedKnowledgePackPath('archive/project.zip'), isTrue);
    expect(isSupportedKnowledgePackPath('design/model.blend'), isTrue);
    expect(
      isSupportedKnowledgePackPath('node_modules/package/index.js'),
      isFalse,
    );
    expect(isSupportedKnowledgePackPath('.env'), isFalse);
    expect(isSupportedKnowledgePackPath('private/key.pem'), isFalse);
  });

  testWidgets('el diálogo avisa de los archivos que se omitirán', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgePackDialog(
          files: [
            LocalKnowledgeFile(
              relativePath: 'docs/guide.md',
              bytes: Uint8List.fromList([35, 32, 71, 117, 105, 100, 101]),
            ),
          ],
          ignoredCount: 3,
          tx: (_, fallback) => fallback,
        ),
      ),
    );

    expect(find.text('1 archivos preparados'), findsOneWidget);
    expect(
      find.text(
        '3 archivos se omitirán por seguridad, tamaño o error de lectura',
      ),
      findsOneWidget,
    );
  });

  testWidgets('el pack permite asignar visibilidad y etiquetas al cargar', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgePackDialog(
          files: [
            LocalKnowledgeFile(
              relativePath: 'scripts/deploy.sh',
              bytes: Uint8List.fromList([101, 99, 104, 111]),
            ),
          ],
          tx: (_, fallback) => fallback,
        ),
      ),
    );

    await tester.tap(find.byType(MultiSelectDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'public'));
    await tester.pump();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('public'), findsOneWidget);
    expect(find.byIcon(Icons.public_outlined), findsNothing);
  });

  testWidgets('ofrece contenido sincronizable o sólo referencias', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: KnowledgePackDialog(
          files: [
            LocalKnowledgeFile(
              relativePath: 'scripts/deploy.sh',
              bytes: Uint8List.fromList([101, 99, 104, 111]),
            ),
          ],
          tx: (_, fallback) => fallback,
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.text('Subir y permitir resincronización'), findsNothing);
    await tester.tap(find.text('Catalogar sólo referencias').last);
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Sólo se guardan rutas y metadatos. El agente podrá ver el catálogo, pero no leer el contenido local.',
      ),
      findsOneWidget,
    );
  });
}
