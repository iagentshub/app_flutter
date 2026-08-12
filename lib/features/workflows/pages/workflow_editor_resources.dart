part of 'workflow_editor_page.dart';

extension _WorkflowEditorResources on _WorkflowEditorPageState {
  Future<void> _loadResources() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _refresh(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loadingAgents = false;
      });
      return;
    }
    try {
      final results = await Future.wait([
        AgentsRepository(apiClient: widget.apiClient).listAgents(token),
        ConnectionsRepository(
          apiClient: widget.apiClient,
        ).listConnections(token, cache: false),
      ]);
      if (!mounted) return;
      _refresh(() {
        _agents = results[0] as List<AgentItem>;
        _llmOrchestrations = (results[1] as List<ConnectionItem>)
            .where((connection) => connection.type == 'llm_orchestration')
            .toList();
        if (_llmOrchestrationConnectionId != null &&
            !_llmOrchestrations.any(
              (item) => item.id == _llmOrchestrationConnectionId,
            )) {
          _llmOrchestrationConnectionId = null;
        }
        _loadingAgents = false;
      });
    } catch (_) {
      if (!mounted) return;
      _refresh(() {
        _error = _tx(
          'workflow_editor.error_load_agents',
          'No se pudieron cargar los agentes disponibles',
        );
        _loadingAgents = false;
      });
    }
  }
}
