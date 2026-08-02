import 'dart:convert';

import '../../../core/network/api_repository.dart';
import '../../../models/agents/agent_builder_models.dart';
import '../../../models/chat/chat_models.dart';

class SkillBuilderRepository extends ApiRepository {
  SkillBuilderRepository({required super.apiClient});

  Stream<AgentBuilderEvent> streamChat(
    String token, {
    required String connectionId,
    required List<ChatMessage> messages,
  }) async* {
    final lines = apiClient.postStream(
      '/api/skill-builder/chat',
      gaToken: token,
      body: {
        'connection_id': connectionId,
        'messages': messages.map((message) => message.toJson()).toList(),
        'mode': 'guided',
      },
    );

    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final raw = line.substring(6).trim();
      if (raw.isEmpty) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          yield AgentBuilderEvent.fromJson(decoded);
        }
      } catch (_) {
        // Keep-alives and malformed provider fragments are not UI events.
      }
    }
  }
}
