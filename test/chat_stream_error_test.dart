import 'dart:async';
import 'dart:convert';

import 'package:app_flutter/core/network/api_client.dart';
import 'package:app_flutter/core/network/page_result.dart';
import 'package:app_flutter/features/agents/pages/chat_page.dart';
import 'package:app_flutter/features/agents/repositories/chat_repository.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:app_flutter/models/auth/session_user.dart';
import 'package:app_flutter/models/chat/chat_models.dart';
import 'package:app_flutter/shared/state/backend_controller.dart';
import 'package:app_flutter/shared/state/locale_controller.dart';
import 'package:app_flutter/shared/state/session_controller.dart';
import 'package:app_flutter/shared/widgets/animated_iagents_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/memory_secure_store.dart';

class _ControllableChatRepository extends ChatRepository {
  _ControllableChatRepository({required super.apiClient});

  bool streamCancelled = false;
  late final events = StreamController<ChatStreamEvent>.broadcast(
    onCancel: () => streamCancelled = true,
  );

  @override
  Future<PageResult<ChatConversation>> listConversationPage(
    String token,
    String agentId, {
    int limit = 50,
    String? cursor,
  }) async => const PageResult(
    items: [ChatConversation(id: 'conversation-1', title: 'Prueba')],
    hasMore: false,
  );

  @override
  Future<PageResult<ChatMessage>> getMessagesPage(
    String token,
    String agentId,
    String conversationId, {
    int limit = 100,
    String? cursor,
  }) async => const PageResult(items: [], hasMore: false);

  @override
  Stream<ChatStreamEvent> streamChat(
    String token,
    String agentId, {
    required List<ChatMessage> messages,
    String? conversationId,
    List<String>? attachedKnowledgeIds,
  }) => events.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'un evento SSE de error detiene la animación y permite reenviar',
    (tester) async {
      SharedPreferences.setMockInitialValues({'app_language': 'es'});
      final backend = await BackendController.bootstrap();
      final locale = await LocaleController.bootstrap();
      final session = await SessionController.bootstrap(
        secureStore: MemorySecureStore(),
      );
      await session.login(
        token: 'user-token',
        user: const SessionUser(username: 'ada', role: 'user'),
        remember: false,
      );
      final httpClient = MockClient(
        (_) async => http.Response(
          jsonEncode(<Object>[]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      );
      final apiClient = ApiClient(backend, client: httpClient);
      final repository = _ControllableChatRepository(apiClient: apiClient);

      await tester.pumpWidget(
        MaterialApp(
          home: ChatPage(
            agent: const AgentItem(
              raw: {'id': 'agent-1', 'name': 'Agente de prueba'},
            ),
            apiClient: apiClient,
            sessionController: session,
            localeController: locale,
            chatRepository: repository,
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 20 && find.byIcon(Icons.send).evaluate().isEmpty;
        attempt += 1
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.enterText(find.byType(TextField).last, 'hola');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      expect(find.byIcon(Icons.stop), findsOneWidget);
      expect(find.byType(IAgentsLoadingMark), findsOneWidget);

      repository.events.add(
        const ChatStreamEvent(type: 'error', message: 'Error controlado'),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Error controlado'), findsOneWidget);
      expect(find.byIcon(Icons.stop), findsNothing);
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.byType(IAgentsLoadingMark), findsNothing);
      expect(repository.streamCancelled, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await repository.events.close();
      session.dispose();
      locale.dispose();
    },
  );

  testWidgets('muestra los avisos de contexto sin terminar el stream', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'app_language': 'es'});
    final backend = await BackendController.bootstrap();
    final locale = await LocaleController.bootstrap();
    final session = await SessionController.bootstrap(
      secureStore: MemorySecureStore(),
    );
    await session.login(
      token: 'user-token',
      user: const SessionUser(username: 'ada', role: 'user'),
      remember: false,
    );
    final apiClient = ApiClient(
      backend,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<Object>[]),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final repository = _ControllableChatRepository(apiClient: apiClient);

    await tester.pumpWidget(
      MaterialApp(
        home: ChatPage(
          agent: const AgentItem(
            raw: {'id': 'agent-1', 'name': 'Agente de prueba'},
          ),
          apiClient: apiClient,
          sessionController: session,
          localeController: locale,
          chatRepository: repository,
        ),
      ),
    );
    for (
      var attempt = 0;
      attempt < 20 && find.byIcon(Icons.send).evaluate().isEmpty;
      attempt += 1
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.enterText(find.byType(TextField).last, 'hola');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    repository.events.add(
      const ChatStreamEvent(
        type: 'context_warning',
        code: 'context_truncated',
        message: 'fallback',
        sources: ['Knowledge: handbook'],
      ),
    );
    await tester.pump();

    expect(
      find.text(
        'Parte del contexto se recortó para respetar el límite del modelo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Knowledge: handbook'), findsOneWidget);
    expect(find.byIcon(Icons.stop), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await repository.events.close();
    session.dispose();
    locale.dispose();
  });
}
