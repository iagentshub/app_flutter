part of '../pages/workflow_editor_page.dart';

extension _WorkflowEditorMobile on _WorkflowEditorPageState {
  Widget _buildMobileCanvasToolbar() {
    return WorkflowEditorToolbar(
      stepCount: _steps.length,
      connectionCount: _steps.connectionCount,
      issueCount: _issues.length,
      stepsLabel: _tx('workflows.steps_suffix'),
      connectionsLabel: _tx('workflows.connections_suffix'),
      issuesLabel: _tx('workflow_editor.issues_suffix'),
      autoLayoutLabel: _tx('workflow_editor.auto_layout'),
      onAutoLayout: _autoLayout,
      addLabel: _tx('workflow_editor.add_step_btn'),
      onAdd: _addStep,
      onIssuesPressed: _issues.isEmpty
          ? null
          : () => _refresh(() => _mobileSection = 0),
    );
  }

  Widget _buildMobileEditor() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              actions: [
                TertiaryButton(
                  onPressed: () => _refresh(() => _error = null),
                  child: Text(_tx('common.close')),
                ),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _mobileSection,
              children: [
                SingleChildScrollView(
                  key: const ValueKey('workflow-mobile-details'),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      WorkflowMetadataCard(
                        nameController: _nameController,
                        descriptionController: _descriptionController,
                        llmOrchestrations: _llmOrchestrations,
                        llmOrchestrationConnectionId:
                            _llmOrchestrationConnectionId,
                        onLlmOrchestrationChanged: (value) => _refresh(
                          () => _llmOrchestrationConnectionId = value,
                        ),
                        isPublic: _labels.contains('public'),
                        onChanged: () => _refresh(() {}),
                        onVisibilityChanged: (isPublic) => _refresh(() {
                          _labels = [
                            for (final label in _labels)
                              if (label != 'private' && label != 'public')
                                label,
                            isPublic ? 'public' : 'private',
                          ];
                        }),
                        selectedLanguageLabels: _labels
                            .where(isLanguageLabel)
                            .toSet(),
                        onLanguageLabelsChanged: (next) => _refresh(() {
                          _labels = [
                            for (final label in _labels)
                              if (!isLanguageLabel(label)) label,
                            ...next,
                          ];
                        }),
                        tx: _tx,
                      ),
                      const SizedBox(height: 12),
                      WorkflowIssuesPanel(
                        issues: _issues,
                        title: _tx('workflow_editor.issues_title'),
                        translate: _tx,
                        onSelectNode: (id) => _refresh(() {
                          _selectedStepId = id;
                          _mobileSection = 2;
                        }),
                      ),
                    ],
                  ),
                ),
                Column(
                  key: const ValueKey('workflow-mobile-canvas'),
                  children: [
                    _buildMobileCanvasToolbar(),
                    Expanded(child: _buildCanvas()),
                  ],
                ),
                Padding(
                  key: const ValueKey('workflow-mobile-inspector'),
                  padding: const EdgeInsets.all(12),
                  child: _buildInspector(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
