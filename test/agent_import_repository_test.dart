import 'dart:convert';
import 'dart:typed_data';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/agents/repositories/agent_import_repository.dart';
import 'package:app_flutter/features/knowledge/models/local_knowledge_file.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'sube un directorio progresivamente y lee un archivo cada vez',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = await BackendController.bootstrap();
      final requests = <http.Request>[];
      var loadedFiles = 0;
      var simultaneousLoads = 0;
      var maximumSimultaneousLoads = 0;
      final client = ApiClient(
        backend,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/upload-sessions')) {
            return _json({'session_id': 'upload-1', 'total_files': 2});
          }
          if (request.url.path.endsWith('/complete')) {
            return _json({
              'components': <Object>[],
              'issues': <Object>[],
              'ignored_paths': <Object>[],
              'session_id': 'review-1',
            });
          }
          return _json({'ok': true});
        }),
      );
      addTearDown(client.close);
      final repository = AgentImportRepository(apiClient: client);

      LocalKnowledgeFile deferred(String path, int byte) =>
          createDeferredLocalKnowledgeFile(
            relativePath: path,
            readBytes: () async {
              simultaneousLoads++;
              maximumSimultaneousLoads =
                  simultaneousLoads > maximumSimultaneousLoads
                  ? simultaneousLoads
                  : maximumSimultaneousLoads;
              loadedFiles++;
              final result = Uint8List.fromList([byte]);
              simultaneousLoads--;
              return result;
            },
          );

      final plan = await repository.previewDirectory(
        'token',
        files: [deferred('agents/a.md', 1), deferred('agents/b.md', 2)],
      );

      expect(plan.sessionId, 'review-1');
      expect(loadedFiles, 2);
      expect(maximumSimultaneousLoads, 1);
      expect(requests.map((request) => request.url.path), [
        '/api/agents/import/directory/upload-sessions',
        '/api/agents/import/directory/upload-sessions/upload-1/files',
        '/api/agents/import/directory/upload-sessions/upload-1/files',
        '/api/agents/import/directory/upload-sessions/upload-1/complete',
      ]);
      expect(requests[1].body, contains('agents/a.md'));
      expect(requests[2].body, contains('agents/b.md'));
    },
  );
}

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);
