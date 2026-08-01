import 'dart:convert';

import '../../../core/network/api_repository.dart';
import '../../../models/workflows/workflow_models.dart';

class WorkflowsRepository extends ApiRepository {
  WorkflowsRepository({required super.apiClient});

  Future<List<WorkflowItem>> listWorkflows(
    String token, {
    bool includeInactive = false,
  }) async {
    final query = includeInactive ? '?include_inactive=true' : '';
    final response = await apiClient.get(
      '/api/workflows$query',
      gaToken: token,
      cache: true,
    );
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => WorkflowItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getWorkflow(String token, String id) async {
    final response = await apiClient.get(
      '/api/workflows/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
    return response.json;
  }

  Future<Map<String, dynamic>> saveWorkflow(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await apiClient.post(
      '/api/workflows',
      gaToken: token,
      body: payload,
    );
    return response.json;
  }

  Future<void> deleteWorkflow(String token, String id) async {
    await apiClient.delete(
      '/api/workflows/${Uri.encodeComponent(id)}',
      gaToken: token,
    );
  }

  Future<void> setWorkflowActive(String token, String id, bool active) =>
      setActive(token, 'workflows', id, active);

  /// Ejecuta el workflow y transmite cada evento SSE a medida que llega
  /// (stage_started/stage_done/evaluation_*/workflow_done/error).
  Stream<Map<String, dynamic>> streamRun(
    String token, {
    required String workflowId,
    required String input,
  }) async* {
    final lines = apiClient.postStream(
      '/api/workflows/${Uri.encodeComponent(workflowId)}/run',
      gaToken: token,
      body: {'input': input},
    );
    await for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payloadText = trimmed.substring(5).trim();
      if (payloadText.isEmpty) continue;
      try {
        final payload = jsonDecode(payloadText);
        if (payload is Map<String, dynamic>) yield payload;
      } catch (_) {
        // Ignorar líneas no parseables del stream.
      }
    }
  }
}
