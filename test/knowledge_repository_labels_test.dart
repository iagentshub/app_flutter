import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/knowledge/repositories/knowledge_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('texto, URL y documento conservan las labels de idioma', () async {
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
    const labels = ['private', 'lang_es', 'lang_en'];

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

    expect(jsonDecode(requests[0].body)['labels'], labels);
    expect(jsonDecode(requests[1].body)['labels'], labels);
    expect(requests[2].body, contains('name="labels"'));
    expect(requests[2].body, contains(jsonEncode(labels)));
  });
}
