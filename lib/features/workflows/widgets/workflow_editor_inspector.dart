part of '../pages/workflow_editor_page.dart';

extension _WorkflowEditorInspector on _WorkflowEditorPageState {
  Widget _buildInspector() {
    final index = _steps.indexWhere((step) => step.id == _selectedStepId);
    if (index < 0) {
      return Center(child: Text(_tx('workflow_editor.select_node_hint')));
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _tx('workflow_editor.inspector_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${index + 1}/${_steps.length}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildStepCard(index, key: ValueKey('inspector-${_steps[index].id}')),
      ],
    );
  }

  void _selectStep(String id) {
    _refresh(() => _selectedStepId = id);
    _inspectorTabs.animateTo(0);
  }

  void _selectIssueNode(String id) {
    _refresh(() => _selectedStepId = id);
    _inspectorTabs.animateTo(0);
  }

  Widget _buildIssuesInspector() {
    if (_issues.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      return Center(
        key: const ValueKey('workflow-inspector-issues-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 30,
              color: colors.primary,
            ),
            const SizedBox(height: 10),
            Text(_tx('workflow_editor.no_issues')),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      key: const ValueKey('workflow-inspector-issues'),
      child: WorkflowIssuesPanel(
        issues: _issues,
        title: _tx('workflow_editor.issues_title'),
        translate: _tx,
        onSelectNode: _selectIssueNode,
      ),
    );
  }
}
