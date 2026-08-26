import 'package:flutter/material.dart';

import '../../../models/agents/agent_import_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import 'agent_resource_picker_dialog.dart';

Future<AgentResourceSelection?> showAgentImportPreviewDialog({
  required BuildContext context,
  required AgentImportPreview preview,
  required String Function(String path) tx,
  List<AgentResourceOption> resourceOptions = const [],
}) async => showAppDialog<AgentResourceSelection>(
  context: context,
  builder: (_) => _AgentImportPreviewDialog(
    preview: preview,
    resourceOptions: resourceOptions,
    tx: tx,
  ),
);

class _AgentImportPreviewDialog extends StatefulWidget {
  const _AgentImportPreviewDialog({
    required this.preview,
    required this.resourceOptions,
    required this.tx,
  });

  final AgentImportPreview preview;
  final List<AgentResourceOption> resourceOptions;
  final String Function(String path) tx;

  @override
  State<_AgentImportPreviewDialog> createState() =>
      _AgentImportPreviewDialogState();
}

class _AgentImportPreviewDialogState extends State<_AgentImportPreviewDialog> {
  static const _unlinked = '';
  final Map<String, String> _selectedByReference = {};
  late final List<AgentImportReference> _references;
  late final Map<String, AgentResourceOption> _optionsById;

  AgentImportPreview get preview => widget.preview;
  String Function(String path) get tx => widget.tx;

  @override
  void initState() {
    super.initState();
    _references = preview.references
        .where((item) => item.type != null)
        .toList();
    _optionsById = {
      for (final option in widget.resourceOptions) option.id: option,
    };
    for (final reference in _references) {
      _selectedByReference[reference.key] = reference.selectedId ?? _unlinked;
    }
  }

  Future<void> _pickResource(AgentImportReference reference) async {
    final type = reference.type;
    if (type == null) return;
    final selected = _selectedByReference[reference.key];
    final result = await showAppDialog<AgentResourceSelection>(
      context: context,
      builder: (_) => AgentResourcePickerDialog(
        options: widget.resourceOptions,
        initial: AgentResourceSelection()
          ..idsFor(type).addAll(
            selected == null || selected.isEmpty ? const [] : [selected],
          ),
        tx: tx,
        allowedTypes: {type},
        singleSelection: true,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _selectedByReference[reference.key] =
          result.idsFor(type).firstOrNull ?? _unlinked;
    });
  }

  AgentResourceSelection _selection() {
    final result = AgentResourceSelection();
    for (final reference in _references) {
      final id = _selectedByReference[reference.key] ?? _unlinked;
      final type = reference.type;
      if (id.isNotEmpty && type != null) result.idsFor(type).add(id);
    }
    return result;
  }

  String _issueText(AgentImportIssue issue) {
    final base = tx('agents.import_issue_${issue.code}');
    if (issue.values.isNotEmpty) return '$base: ${issue.values.join(', ')}';
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = preview.draft;
    return AlertDialog(
      title: Text(tx('agents.import_preview_title')),
      contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      content: SizedBox(
        width: dialogContentWidth(context, 620),
        height: dialogContentHeight(context, 620),
        child: ListView(
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.filename,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        tx('agents.import_format_${preview.sourceFormat}'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PreviewField(label: tx('agents.field_name'), value: draft.name),
            _PreviewField(
              label: tx('agents.field_description'),
              value: draft.description,
            ),
            _PreviewField(
              label: tx('agents.field_type'),
              value: draft.agentType,
            ),
            _PreviewField(label: tx('agents.field_model'), value: draft.model),
            const SizedBox(height: 8),
            Text(tx('agents.field_prompt'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  draft.systemPrompt.isEmpty
                      ? tx('agents.import_prompt_empty')
                      : draft.systemPrompt,
                ),
              ),
            ),
            if (_references.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(
                tx('agents.import_resources_title'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                tx('agents.import_resources_description'),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              for (final reference in _references)
                Card(
                  child: ListTile(
                    key: ValueKey('agent-import-resource-${reference.key}'),
                    title: Text(reference.source),
                    subtitle: Text(
                      _optionsById[_selectedByReference[reference.key]]
                              ?.title ??
                          tx('agents.import_resource_unlinked'),
                    ),
                    trailing: const Icon(Icons.search),
                    onTap: () => _pickResource(reference),
                  ),
                ),
            ],
            if (preview.issues.isNotEmpty) ...[
              const SizedBox(height: 18),
              Semantics(
                liveRegion: true,
                child: Text(
                  tx('agents.import_warnings_title'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              for (final issue in preview.issues)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.tertiary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_issueText(issue))),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tx('common.cancel')),
        ),
        PrimaryButton(
          key: const ValueKey('agent-import-review'),
          onPressed: () => Navigator.of(context).pop(_selection()),
          child: Text(tx('agents.import_review_action')),
        ),
      ],
    );
  }
}

class _PreviewField extends StatelessWidget {
  const _PreviewField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
