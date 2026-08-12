import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/public/repositories/public_profile_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('carga los datos sociales que forman el perfil publico', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        expect(request.url.path, '/api/users/alice');
        return http.Response(
          jsonEncode({
            'username': 'alice',
            'avatar_url': '/api/users/alice/avatar',
            'bio': 'Desarrolladora de agentes',
            'languages': ['es', 'en'],
            'email_public': 'alice@example.com',
            'github': 'https://github.com/alice',
            'cv': '# Experiencia',
            'joined_at': '2026-08-01',
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);

    final profile = await PublicProfileRepository(
      apiClient: client,
    ).getProfile('token', 'alice');

    expect(profile.avatarUrl, '/api/users/alice/avatar');
    expect(profile.bio, 'Desarrolladora de agentes');
    expect(profile.languages, ['es', 'en']);
    expect(profile.emailPublic, 'alice@example.com');
    expect(profile.cv, '# Experiencia');
    expect(profile.createdAt, '2026-08-01');
  });

  test('no conserva en caché los recursos públicos de otro usuario', () async {
    SharedPreferences.setMockInitialValues({});
    final backend = await BackendController.bootstrap();
    var requests = 0;
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        expect(request.url.path, '/api/users/alice/resources');
        requests++;
        return http.Response(
          jsonEncode(
            requests == 1
                ? <Map<String, dynamic>>[]
                : [
                    {
                      'resource_type': 'agent',
                      'resource_id': 'agent-publico',
                      'name': 'Agente público',
                      'labels': ['public'],
                    },
                  ],
          ),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.close);
    final repository = PublicProfileRepository(apiClient: client);

    expect(await repository.listResources('token', username: 'alice'), isEmpty);
    final refreshed = await repository.listResources(
      'token',
      username: 'alice',
    );

    expect(requests, 2);
    expect(refreshed.single.resourceId, 'agent-publico');
  });
}
