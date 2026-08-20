import 'dart:typed_data';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/knowledge/dialogs/knowledge_pack_dialog.dart';
import 'package:app_flutter/features/knowledge/dialogs/knowledge_pack_upload_progress_dialog.dart';
import 'package:app_flutter/features/knowledge/models/local_knowledge_file.dart';
import 'package:app_flutter/features/knowledge/repositories/knowledge_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/utils/i18n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/i18n_de_prueba.dart';

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  int attempts = 50,
}) async {
  for (var i = 0; i < attempts; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('No apareció el widget esperado');
}

void main() {
  setUp(cargarTraduccionesDePrueba);

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'continúa tras un fallo, muestra el motivo y permite reintentar',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      final backend = await BackendController.bootstrap();
      var failedOnce = false;
      final client = ApiClient(
        backend,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/upload-sessions')) {
            return http.Response(
              '{"id":"session-1","upload_status":"uploading"}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/files') &&
              request.body.contains('b.md') &&
              !failedOnce) {
            failedOnce = true;
            return http.Response(
              '{"detail":{"code":"invalid_field","message":"Formato dañado"}}',
              422,
              headers: {'content-type': 'application/json'},
            );
          }
          if (request.url.path.endsWith('/complete')) {
            return http.Response(
              '{"id":"pack-1","name":"Pack","file_count":2}',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            '{}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: KnowledgePackUploadProgressDialog(
            repository: KnowledgeRepository(apiClient: client),
            token: 'token',
            draft: KnowledgePackDraft(
              name: 'Pack',
              description: '',
              files: [
                LocalKnowledgeFile(
                  relativePath: 'a.md',
                  bytes: Uint8List.fromList([1]),
                ),
                LocalKnowledgeFile(
                  relativePath: 'b.md',
                  bytes: Uint8List.fromList([2]),
                ),
              ],
              labels: const {'private'},
              sourceMode: 'upload',
            ),
            tx: tr,
          ),
        ),
      );

      await _pumpUntil(tester, find.text('Reintentar fallidos'));
      expect(find.text('2/2'), findsOneWidget);
      expect(find.text('Formato dañado'), findsOneWidget);
      expect(find.textContaining('1 correctos · 1 con error'), findsOneWidget);

      await tester.tap(find.text('Reintentar fallidos'));
      await _pumpUntil(tester, find.text('Carga completada'));
      expect(find.textContaining('2 correctos · 0 con error'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
