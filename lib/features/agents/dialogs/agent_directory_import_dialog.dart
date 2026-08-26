import 'package:flutter/material.dart';

import '../../../models/agents/agent_import_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import 'agent_resource_picker_dialog.dart';

Future<AgentDirectoryImportOptions?> showAgentDirectoryImportDialog({
  required BuildContext context,
  required AgentDirectoryImportPlan plan,
  required List<AgentResourceOption> resourceOptions,
  required String Function(String path) tx,
  AgentResourcePageLoader? pageLoader,
}) => showAppDialog<AgentDirectoryImportOptions>(
  context: context,
  builder: (_) => _AgentDirectoryImportDialog(
    plan: plan,
    resourceOptions: resourceOptions,
    tx: tx,
    pageLoader: pageLoader,
  ),
);

class _AgentDirectoryImportDialog extends StatefulWidget {
  const _AgentDirectoryImportDialog({
    required this.plan,
    required this.resourceOptions,
    required this.tx,
    this.pageLoader,
  });

  final AgentDirectoryImportPlan plan;
  final List<AgentResourceOption> resourceOptions;
  final String Function(String path) tx;
  final AgentResourcePageLoader? pageLoader;

  @override
  State<_AgentDirectoryImportDialog> createState() =>
      _AgentDirectoryImportDialogState();
}

class _AgentDirectoryImportDialogState
    extends State<_AgentDirectoryImportDialog> {
  late final Set<String> _selectedAgents;
  final Map<String, String> _componentActions = {};
  final Map<String, String> _referenceIds = {};
  late final Map<String, AgentResourceOption> _optionsById;

  @override
  void initState() {
    super.initState();
    _selectedAgents = {
      for (final component in widget.plan.components)
        if (component.isAgent) component.id,
    };
    _optionsById = {
      for (final option in widget.resourceOptions) option.id: option,
    };
    for (final component in widget.plan.components) {
      if (!component.isAgent) {
        _componentActions[component.id] = switch (component.defaultAction) {
          'reuse' when component.selectedExistingId != null =>
            'reuse:${component.selectedExistingId}',
          'skip' => 'skip',
          'review' => 'review',
          _ => 'create',
        };
      }
      for (final reference in component.references) {
        if (reference.localComponentId == null) {
          _referenceIds['${component.id}:${reference.key}'] =
              reference.selectedId ?? '';
        }
      }
    }
  }

  Future<void> _pickReference(
    AgentDirectoryComponent agent,
    AgentImportReference reference,
  ) async {
    final type = reference.type;
    if (type == null) return;
    final key = '${agent.id}:${reference.key}';
    final current = _referenceIds[key] ?? '';
    final selection = await showAppDialog<AgentResourceSelection>(
      context: context,
      builder: (_) => AgentResourcePickerDialog(
        options: widget.resourceOptions,
        initial: AgentResourceSelection()
          ..idsFor(type).addAll(current.isEmpty ? const [] : [current]),
        tx: widget.tx,
        allowedTypes: {type},
        singleSelection: true,
        pageLoader: widget.pageLoader,
      ),
    );
    if (!mounted || selection == null) return;
    setState(
      () => _referenceIds[key] = selection.idsFor(type).firstOrNull ?? '',
    );
  }

  AgentDirectoryImportOptions _result() {
    final componentChoices = <Map<String, dynamic>>[];
    for (final component in widget.plan.components.where(
      (item) => !item.isAgent,
    )) {
      final raw = _componentActions[component.id] ?? 'create';
      componentChoices.add({
        'component_id': component.id,
        'action': raw.startsWith('reuse:') ? 'reuse' : raw,
        if (raw.startsWith('reuse:')) 'resource_id': raw.substring(6),
      });
    }
    return AgentDirectoryImportOptions(
      selectedAgentIds: _selectedAgents,
      componentChoices: componentChoices,
      referenceChoices: [
        for (final agent in widget.plan.components.where(
          (item) => item.isAgent,
        ))
          for (final reference in agent.references)
            if (reference.localComponentId == null)
              {
                'agent_component_id': agent.id,
                'reference_key': reference.key,
                'resource_id': _referenceIds['${agent.id}:${reference.key}'],
              },
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final dependencies = widget.plan.components.where((item) => !item.isAgent);
    final agents = widget.plan.components.where((item) => item.isAgent);
    return AlertDialog(
      title: Text(widget.tx('agents.directory_preview_title')),
      content: SizedBox(
        width: dialogContentWidth(context, 680),
        height: dialogContentHeight(context, 680),
        child: ListView(
          children: [
            Text(widget.tx('agents.directory_agents_title')),
            for (final agent in agents)
              CheckboxListTile(
                key: ValueKey('directory-agent-${agent.id}'),
                value: _selectedAgents.contains(agent.id),
                title: Text(agent.name),
                subtitle: Text(agent.sourcePath),
                onChanged: (selected) => setState(() {
                  if (selected ?? false) {
                    _selectedAgents.add(agent.id);
                  } else {
                    _selectedAgents.remove(agent.id);
                  }
                }),
              ),
            if (dependencies.isNotEmpty) ...[
              const Divider(),
              Text(widget.tx('agents.directory_dependencies_title')),
              for (final component in dependencies)
                DropdownButtonFormField<String>(
                  key: ValueKey('directory-component-${component.id}'),
                  initialValue: _componentActions[component.id],
                  decoration: InputDecoration(
                    labelText: component.name,
                    helperText: component.sourcePath,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'create',
                      child: Text(widget.tx('agents.directory_action_create')),
                    ),
                    for (final candidate in component.candidates)
                      DropdownMenuItem(
                        value: 'reuse:${candidate.id}',
                        child: Text(
                          widget
                              .tx('agents.directory_action_reuse')
                              .replaceAll('{{name}}', candidate.name),
                        ),
                      ),
                    DropdownMenuItem(
                      value: 'skip',
                      child: Text(widget.tx('agents.directory_action_skip')),
                    ),
                    if (_componentActions[component.id] == 'review')
                      DropdownMenuItem(
                        value: 'review',
                        enabled: false,
                        child: Text(
                          widget.tx('agents.directory_action_review'),
                        ),
                      ),
                  ],
                  onChanged: component.securityBlocked
                      ? null
                      : (value) => setState(
                          () =>
                              _componentActions[component.id] = value ?? 'skip',
                        ),
                ),
            ],
            for (final agent in agents)
              for (final reference in agent.references)
                if (reference.localComponentId == null)
                  ListTile(
                    title: Text('${agent.name}: ${reference.source}'),
                    subtitle: Text(
                      _optionsById[_referenceIds['${agent.id}:${reference.key}']]
                              ?.title ??
                          widget.tx('agents.import_resource_unlinked'),
                    ),
                    trailing: const Icon(Icons.search),
                    onTap: () => _pickReference(agent, reference),
                  ),
            if (widget.plan.ignoredPaths.isNotEmpty)
              Text(
                widget
                    .tx('agents.directory_ignored_count')
                    .replaceAll(
                      '{{count}}',
                      '${widget.plan.ignoredPaths.length}',
                    ),
              ),
          ],
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel')),
        ),
        PrimaryButton(
          key: const ValueKey('directory-import-apply'),
          onPressed:
              _selectedAgents.isEmpty ||
                  _componentActions.containsValue('review')
              ? null
              : () => Navigator.of(context).pop(_result()),
          child: Text(widget.tx('agents.directory_import_action')),
        ),
      ],
    );
  }
}
