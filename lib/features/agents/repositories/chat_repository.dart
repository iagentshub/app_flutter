import 'dart:convert';

import '../../../core/network/api_repository.dart';
import '../../../core/network/page_result.dart';
import '../../../models/chat/chat_models.dart';

class ChatRepository extends ApiRepository {
  ChatRepository({required super.apiClient});

  Future<List<ChatConversation>> listConversations(
    String token,
    String agentId,
  ) async {
    return (await listConversationPage(token, agentId)).items;
  }

  Future<PageResult<ChatConversation>> listConversationPage(
    String token,
    String agentId, {
    int limit = 50,
    String? cursor,
  }) async {
    final uri = Uri(
      path: '/api/chats/${Uri.encodeComponent(agentId)}',
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final response = await apiClient.get(
      uri.toString(),
      gaToken: token,
      cache: false,
    );
    return PageResult.fromResponse(response, ChatConversation.fromJson);
  }

  Future<ChatConversation> createConversation(
    String token,
    String agentId, {
    String title = '',
  }) async {
    final response = await apiClient.post(
      '/api/chats/${Uri.encodeComponent(agentId)}',
      gaToken: token,
      body: {'title': title},
    );
    return ChatConversation.fromJson(response.json);
  }

  Future<List<ChatMessage>> getMessages(
    String token,
    String agentId,
    String conversationId,
  ) async {
    return (await getMessagesPage(token, agentId, conversationId)).items;
  }

  Future<PageResult<ChatMessage>> getMessagesPage(
    String token,
    String agentId,
    String conversationId, {
    int limit = 100,
    String? cursor,
  }) async {
    final uri = Uri(
      path:
          '/api/chats/${Uri.encodeComponent(agentId)}/${Uri.encodeComponent(conversationId)}',
      queryParameters: {
        'limit': '$limit',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    final response = await apiClient.get(uri.toString(), gaToken: token);
    return PageResult.fromResponse(response, ChatMessage.fromJson);
  }

  Future<void> deleteConversation(
    String token,
    String agentId,
    String conversationId,
  ) async {
    await apiClient.delete(
      '/api/chats/${Uri.encodeComponent(agentId)}/${Uri.encodeComponent(conversationId)}',
      gaToken: token,
    );
  }

  /// Envía el historial y transmite los eventos SSE de la respuesta del agente.
  Stream<ChatStreamEvent> streamChat(
    String token,
    String agentId, {
    required List<ChatMessage> messages,
    String? conversationId,
    List<String>? attachedKnowledgeIds,
  }) async* {
    final lines = apiClient.postStream(
      '/api/agents/${Uri.encodeComponent(agentId)}/chat',
      gaToken: token,
      body: {
        'messages': messages.map((m) => m.toJson()).toList(),
        if (conversationId != null && conversationId.isNotEmpty)
          'conversation_id': conversationId,
        if (attachedKnowledgeIds != null && attachedKnowledgeIds.isNotEmpty)
          'attached_knowledge_ids': attachedKnowledgeIds,
      },
    );

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final raw = line.substring(6).trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          yield ChatStreamEvent.fromJson(decoded);
        }
      } catch (_) {
        // Ignorar líneas no-JSON (comentarios keep-alive del SSE, etc.).
      }
    }
  }
}
