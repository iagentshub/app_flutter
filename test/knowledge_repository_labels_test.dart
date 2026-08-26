import 'dart:convert';
import 'dart:typed_data';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/knowledge/models/local_knowledge_file.dart';
import 'package:app_flutter/features/knowledge/repositories/knowledge_repository.dart';
import 'package:app_flutter/models/knowledge/knowledge_models.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('creación y edición conservan las labels seleccionadas', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final requests = <http.Request>[];
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);
    final repository = KnowledgeRepository(apiClient: client);
    const labels = ['public', 'production', 'favorite', 'lang_es', 'lang_en'];

    await repository.addText(
      'token',
      title: 'Manual',
      content: 'Contenido',
      labels: labels,
    );
    await repository.addUrl(
      'token',
      url: 'https://example.com',
      labels: labels,
    );
    await repository.uploadDocument(
      'token',
      fileName: 'manual.txt',
      fileBytes: utf8.encode('Contenido'),
      labels: labels,
    );
    await repository.updateItem(
      'token',
      'item-1',
      name: 'Manual actualizado',
      labels: labels,
    );
    await repository.updatePack(
      'token',
      'pack-1',
      name: 'Pack actualizado',
      description: 'Nueva descripción',
      labels: labels,
    );

    expect(jsonDecode(requests[0].body)['labels'], labels);
    expect(jsonDecode(requests[1].body)['labels'], labels);
    expect(requests[2].body, contains('name="labels"'));
    expect(requests[2].body, contains(jsonEncode(labels)));
    expect(requests[3].method, 'PUT');
    expect(requests[3].url.path, '/api/knowledge/item-1');
    expect(jsonDecode(requests[3].body)['name'], 'Manual actualizado');
    expect(jsonDecode(requests[3].body)['labels'], labels);
    expect(requests[4].url.path, '/api/knowledge/packs/pack-1');
    expect(jsonDecode(requests[4].body), {
      'name': 'Pack actualizado',
      'description': 'Nueva descripción',
      'labels': labels,
    });
  });

  test('packs envían modo de origen y permiten resincronizar', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final requests = <http.Request>[];
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);
    final repository = KnowledgeRepository(apiClient: client);
    final files = [
      LocalKnowledgeFile(
        relativePath: 'scripts/run.sh',
        bytes: Uint8List.fromList([101, 99, 104, 111]),
      ),
    ];

    await repository.synchronizePack(
      'token',
      pack: const KnowledgePack(raw: {'id': 'pack-1', 'source_mode': 'sync'}),
      files: files,
    );
    await repository.createPackUploadSession(
      'token',
      name: 'Carga progresiva',
      description: '',
      sourceMode: 'upload',
      labels: const ['private'],
      totalFiles: 1,
    );
    var progress = 0.0;
    await repository.uploadPackSessionFile(
      'token',
      sessionId: 'session-1',
      file: files.single,
      referenceOnly: false,
      onProgress: (value) => progress = value,
    );
    await repository.completePackUploadSession('token', 'session-1');
    await repository.cancelPackUploadSession('token', 'session-2');

    expect(requests[0].url.path, '/api/knowledge/packs/pack-1/sync-manifest');
    expect(requests[0].body, contains('checksum'));
    expect(requests[1].url.path, '/api/knowledge/packs/pack-1/sync');
    expect(requests[1].body, contains('scripts/run.sh'));
    expect(requests[1].body, contains('manifest'));
    expect(requests[2].url.path, '/api/knowledge/packs/upload-sessions');
    expect(jsonDecode(requests[2].body)['total_files'], 1);
    expect(
      requests[3].url.path,
      '/api/knowledge/packs/upload-sessions/session-1/files',
    );
    expect(requests[3].body, contains('reported_checksum'));
    expect(requests[3].body, contains('reported_mime_type'));
    expect(progress, 1);
    expect(
      requests[4].url.path,
      '/api/knowledge/packs/upload-sessions/session-1/complete',
    );
    expect(requests[5].method, 'DELETE');
  });

  test('documentos y packs usan sus endpoints de activación', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final requests = <http.Request>[];
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);
    final repository = KnowledgeRepository(apiClient: client);

    await repository.setItemActive('token', 'doc 1', false);
    await repository.setPackActive('token', 'pack 1', true);

    expect(requests.map((request) => request.url.path).toList(), [
      '/api/knowledge/doc%201/deactivate',
      '/api/knowledge/packs/pack%201/activate',
    ]);
  });
}
