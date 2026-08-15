import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/features/agents/repositories/chat_repository.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('propaga el cursor y centraliza los metadatos de página', () async {
    final backend = await BackendController.bootstrap();
    Uri? seen;
    final client = ApiClient(
      backend,
      client: MockClient((request) async {
        seen = request.url;
        return http.Response(
          jsonEncode([
            {'id': 'conversation-2', 'title': 'Dos'},
          ]),
          200,
          headers: {'x-next-cursor': 'cursor-siguiente', 'x-has-more': 'true'},
        );
      }),
    );
    addTearDown(client.close);

    final page = await ChatRepository(
      apiClient: client,
    ).listConversationPage('token', 'agent 1', limit: 25, cursor: 'cursor-1');

    expect(seen?.queryParameters, {'limit': '25', 'cursor': 'cursor-1'});
    expect(page.items.single.id, 'conversation-2');
    expect(page.nextCursor, 'cursor-siguiente');
    expect(page.hasMore, isTrue);
  });

  test('decodifica el id de mensajes para deduplicar páginas', () async {
    final backend = await BackendController.bootstrap();
    final client = ApiClient(
      backend,
      client: MockClient(
        (_) async => http.Response(
          '[{"id":"message-1","role":"user","content":"Hola"}]',
          200,
          headers: {'x-has-more': 'false'},
        ),
      ),
    );
    addTearDown(client.close);

    final page = await ChatRepository(
      apiClient: client,
    ).getMessagesPage('token', 'agent', 'conversation');

    expect(page.items.single.id, 'message-1');
    expect(page.hasMore, isFalse);
  });
}
