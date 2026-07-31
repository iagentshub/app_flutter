import 'dart:convert';

import '../../../core/network/api_repository.dart';
import '../../../models/chat/chat_models.dart';

class ChatRepository extends ApiRepository {
  ChatRepository({required super.apiClient});

  Future<List<ChatConversation>> listConversations(
    String token,
    String agentId,
  ) async {
    final response = await apiClient.get(
      '/api/chats/${Uri.encodeComponent(agentId)}',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(ChatConversation.fromJson)
        .toList();
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
    final response = await apiClient.get(
      '/api/chats/${Uri.encodeComponent(agentId)}/${Uri.encodeComponent(conversationId)}',
      gaToken: token,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
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
  }) async* {
    final lines = apiClient.postStream(
      '/api/agents/${Uri.encodeComponent(agentId)}/chat',
      gaToken: token,
      body: {
        'messages': messages.map((m) => m.toJson()).toList(),
        if (conversationId != null && conversationId.isNotEmpty)
          'conversation_id': conversationId,
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
