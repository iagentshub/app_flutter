import 'package:app_flutter/models/admin/admin_explore_models.dart';
import 'package:app_flutter/models/agents/agent_builder_models.dart';
import 'package:app_flutter/models/agents/agent_models.dart';
import 'package:app_flutter/models/chat/chat_models.dart';
import 'package:app_flutter/models/connections/connection_models.dart';
import 'package:app_flutter/models/workflows/llm_orchestration_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses an ordered balanced LLM orchestration', () {
    const item = LlmOrchestrationItem(
      raw: {
        'id': 'route-1',
        'name': 'Code router',
        'mode': 'balanced',
        'router_connection_id': 'router',
        'candidates': [
          {'connection_id': 'fast', 'routing_hint': 'fast tasks'},
          {'connection_id': 'smart', 'routing_hint': 'complex code'},
        ],
      },
    );

    expect(item.mode, 'balanced');
    expect(item.routerConnectionId, 'router');
    expect(item.candidates.map((candidate) => candidate.connectionId), [
      'fast',
      'smart',
    ]);
  });

  test('agent exposes an LLM orchestration as its connection', () {
    const agent = AgentItem(
      raw: {
        'id': 'agent',
        'name': 'Agent',
        'connection_id': 'llm-orchestration:route-1',
      },
    );
    expect(agent.connectionId, 'llm-orchestration:route-1');
  });

  test('LLM orchestration connection facade is read-only and virtual', () {
    const connection = ConnectionItem(
      raw: {
        'id': 'llm-orchestration:route-1',
        'name': 'Code router',
        'type': 'llm_orchestration',
        'model': 'balanced',
        'is_virtual': true,
        'read_only': true,
      },
    );

    expect(connection.isVirtual, isTrue);
    expect(connection.type, 'llm_orchestration');
    expect(connection.model, 'balanced');
  });

  test('routing SSE notices preserve their message', () {
    final event = ChatStreamEvent.fromJson({
      'type': 'routing_failover',
      'message': 'Primary failed; using backup.',
    });
    expect(event.type, 'routing_failover');
    expect(event.message, contains('backup'));
  });

  test('SSE models preserve stable error codes', () {
    final chat = ChatStreamEvent.fromJson({
      'type': 'error',
      'code': 'credential_unreadable',
      'message': 'fallback',
    });
    final builder = AgentBuilderEvent.fromJson({
      'type': 'error',
      'code': 'credential_unreadable',
      'message': 'fallback',
    });

    expect(chat.code, 'credential_unreadable');
    expect(builder.code, 'credential_unreadable');
  });

  test('admin explore accepts private LLM orchestrations', () {
    final item = AdminExploreItem.fromJson({
      'resource_type': 'llm_orchestration',
      'id': 'route-1',
      'name': 'Private route',
    });
    expect(item.type, AdminResourceType.llmOrchestration);
  });
}
