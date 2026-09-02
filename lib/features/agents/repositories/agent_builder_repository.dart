import 'dart:convert';

import '../../../core/network/api_repository.dart';
import '../../../models/agents/agent_builder_models.dart';
import '../../../models/chat/chat_models.dart';

class AgentBuilderRepository extends ApiRepository {
  AgentBuilderRepository({required super.apiClient});

  /// Envía la conversación al constructor de agentes por IA y transmite los
  /// eventos SSE de la respuesta (`progress`, `error`, `builder_done`).
  Stream<AgentBuilderEvent> streamChat(
    String token, {
    required String connectionId,
    required List<ChatMessage> messages,
    List<Map<String, String>> skills = const [],
    List<Map<String, String>> knowledge = const [],
    String mode = 'auto',
  }) async* {
    final lines = apiClient.postStream(
      '/api/agent-builder/chat',
      gaToken: token,
      body: {
        'connection_id': connectionId,
        'messages': messages.map((m) => m.toJson()).toList(),
        'resources': {'skills': skills, 'knowledge': knowledge},
        'mode': mode,
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
        // Ignorar líneas no-JSON (comentarios keep-alive del SSE, etc.).
      }
    }
  }
}
