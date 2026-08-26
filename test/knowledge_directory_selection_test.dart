import 'dart:typed_data';

import 'package:app_flutter/core/config/directory_import_policy.dart';
import 'package:app_flutter/features/knowledge/dialogs/knowledge_pack_dialog.dart';
import 'package:app_flutter/features/knowledge/models/local_knowledge_file.dart';
import 'package:app_flutter/shared/widgets/multi_select_dropdown.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/i18n_de_prueba.dart';

void main() {
  setUp(cargarTraduccionesDePrueba);

  test('clasifica documentos, código e imágenes sin incluir secretos', () {
    bool supports(String path) => DirectoryImportPolicy.supportsPath(
      DirectoryImportKind.knowledgePack,
      path,
    );

    expect(supports('docs/README.md'), isTrue);
    expect(supports('scripts/deploy.py'), isTrue);
    expect(supports('skills/SKILL.md'), isTrue);
    expect(supports('photos/diagram.png'), isTrue);
    expect(supports('photos/large-image.jpg'), isTrue);
    expect(supports('photos/capture.heic'), isTrue);
    expect(supports('archive/project.zip'), isTrue);
    expect(supports('design/model.blend'), isTrue);
    expect(supports('node_modules/package/index.js'), isFalse);
    expect(supports('.env'), isFalse);
    expect(supports('private/key.pem'), isFalse);
  });

  test('la política tipada conserva las reglas para agentes', () {
    expect(
      DirectoryImportPolicy.supportsPath(
        DirectoryImportKind.agent,
        'agents/reviewer.md',
      ),
      isTrue,
    );
    expect(
      DirectoryImportPolicy.supportsPath(
        DirectoryImportKind.agent,
        'node_modules/package/agent.md',
      ),
      isFalse,
    );
    expect(
      DirectoryImportPolicy.supportsPath(
        DirectoryImportKind.agent,
        'private/id_ed25519',
      ),
      isFalse,
    );
  });

  test('una importación de agentes puede omitir el checksum local', () async {
    final file = await createLocalKnowledgeFile(
      relativePath: 'agents/reviewer.md',
      bytes: Uint8List.fromList([35, 32, 65, 103, 101, 110, 116]),
      calculateChecksum: false,
    );

    expect(file.checksum, isEmpty);
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
          tx: tr,
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
          tx: tr,
        ),
      ),
    );

    await tester.tap(find.byType(MultiSelectDropdown<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Público'));
    await tester.pump();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('Público'), findsOneWidget);
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
          tx: tr,
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
