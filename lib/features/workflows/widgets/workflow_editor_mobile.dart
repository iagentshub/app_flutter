part of '../pages/workflow_editor_page.dart';

extension _WorkflowEditorMobile on _WorkflowEditorPageState {
  Widget _buildMobileCanvasToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_steps.length} ${_tx('workflows.steps_suffix', 'pasos')} · '
              '${_steps.connectionCount} '
              '${_tx('workflows.connections_suffix', 'conexiones')}',
              style: Theme.of(context).textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AppIconButton.outlined(
            onPressed: _autoLayout,
            icon: const Icon(Icons.auto_awesome_mosaic_outlined),
            tooltip: _tx('workflow_editor.auto_layout', 'Auto-organizar'),
          ),
          const SizedBox(width: 6),
          AppIconButton.filled(
            onPressed: _addStep,
            icon: const Icon(Icons.add_rounded),
            tooltip: _tx('workflow_editor.add_step_btn', 'Añadir paso'),
          ),
        ],
      ),
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
                  child: Text(_tx('common.close', 'Cerrar')),
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
                        title: _tx(
                          'workflow_editor.issues_title',
                          '{{n}} problemas impiden guardar',
                        ),
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
