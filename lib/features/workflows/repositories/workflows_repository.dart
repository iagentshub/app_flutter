import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../models/workflows/workflow_models.dart';

class WorkflowsRepository {
  WorkflowsRepository({required this.apiClient});

  final ApiClient apiClient;

  Future<List<WorkflowItem>> listWorkflows(String token) async {
    final response = await apiClient.get('/api/workflows', gaToken: token);
    final payload = response.body;
    if (payload is! List) return const [];
    return payload
        .whereType<Map<String, dynamic>>()
        .map((item) => WorkflowItem(raw: item))
        .toList();
  }

  Future<Map<String, dynamic>> getWorkflow(String token, String id) async {
    final response = await apiClient.get('/api/workflows/${Uri.encodeComponent(id)}', gaToken: token);
    return response.json;
  }

  Future<Map<String, dynamic>> saveWorkflow(String token, Map<String, dynamic> payload) async {
    final response = await apiClient.post('/api/workflows', gaToken: token, body: payload);
    return response.json;
  }

  Future<void> deleteWorkflow(String token, String id) async {
    await apiClient.delete('/api/workflows/${Uri.encodeComponent(id)}', gaToken: token);
  }

  Future<WorkflowRunResult> runWorkflow(
    String token, {
    required String workflowId,
    required String input,
  }) async {
    final response = await apiClient.post(
      '/api/workflows/${Uri.encodeComponent(workflowId)}/run',
      gaToken: token,
      body: {'input': input},
    );

    final rawBody = response.body;
    if (rawBody is Map<String, dynamic>) {
      return WorkflowRunResult(
        events: const [],
        finalOutput: rawBody['output'] as String?,
        errorMessage: null,
      );
    }

    final content = rawBody?.toString() ?? '';
    final events = <Map<String, dynamic>>[];
    String? finalOutput;
    String? errorMessage;

    final lines = content.split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;
      final payloadText = trimmed.substring(5).trim();
      if (payloadText.isEmpty) continue;
      try {
        final payload = jsonDecode(payloadText);
        if (payload is! Map<String, dynamic>) continue;
        events.add(payload);
        final type = payload['type'] as String? ?? '';
        if (type == 'workflow_done') {
          finalOutput = payload['output']?.toString();
        }
        if (type == 'error') {
          errorMessage = payload['message']?.toString() ?? 'Error ejecutando workflow';
        }
      } catch (_) {
        // Ignorar líneas no parseables del stream.
      }
    }

    return WorkflowRunResult(events: events, finalOutput: finalOutput, errorMessage: errorMessage);
  }
}
