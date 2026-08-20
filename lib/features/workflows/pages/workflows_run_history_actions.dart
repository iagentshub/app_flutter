part of 'workflows_page.dart';

extension _WorkflowRunHistoryActions on _WorkflowsPageState {
  Future<void> _openRun(WorkflowRun summary) async {
    try {
      final run = await _workflowRuns.detail(summary.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => RunProgressDialog(
          workflowName: run.workflowName,
          definition: run.definition,
          agents: run.agents.map((raw) => AgentItem(raw: raw)).toList(),
          tx: _tx,
          stream: _workflowRuns.events(run.id),
          onCancel: () async {
            await _workflowRuns.cancel(run.id);
          },
        ),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('workflows.run_open_error'), isError: true);
    }
  }

  Future<void> _openRunsPanel() async {
    await _workflowRuns.refresh();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => WorkflowRunsPanel(
        controller: _workflowRuns,
        tx: _tx,
        onOpen: (run) {
          Navigator.of(dialogContext).pop();
          _openRun(run);
        },
      ),
    );
  }
}
