import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/grouped_label_picker.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../models/local_knowledge_file.dart';

class KnowledgePackDraft {
  const KnowledgePackDraft({
    required this.name,
    required this.description,
    required this.files,
    required this.labels,
    required this.sourceMode,
  });

  final String name;
  final String description;
  final List<LocalKnowledgeFile> files;
  final Set<String> labels;
  final String sourceMode;
}

class KnowledgePackDialog extends StatefulWidget {
  const KnowledgePackDialog({
    required this.files,
    required this.tx,
    this.ignoredCount = 0,
    super.key,
  });

  final List<LocalKnowledgeFile> files;
  final int ignoredCount;
  final String Function(String path) tx;

  @override
  State<KnowledgePackDialog> createState() => _KnowledgePackDialogState();
}

class _KnowledgePackDialogState extends State<KnowledgePackDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  Set<String> _selectedLabels = {'private'};
  String _sourceMode = 'upload';

  @override
  void initState() {
    super.initState();
    final firstPath = widget.files.firstOrNull?.relativePath ?? '';
    final inferred = firstPath.contains('/') ? firstPath.split('/').first : '';
    _nameController = TextEditingController(text: inferred);
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      KnowledgePackDraft(
        name: name,
        description: _descriptionController.text.trim(),
        files: widget.files,
        labels: _selectedLabels,
        sourceMode: _sourceMode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.tx('knowledge.pack_dialog_title')),
    content: SizedBox(
      width: dialogContentWidth(context, 560),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('knowledge-pack-name'),
              controller: _nameController,
              autofocus: true,
              maxLength: 160,
              decoration: InputDecoration(
                labelText: widget.tx('knowledge.pack_name'),
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: widget.tx('knowledge.description_label'),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _sourceMode,
              decoration: InputDecoration(
                labelText: widget.tx('knowledge.pack_source_mode'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'upload',
                  child: Text(widget.tx('knowledge.pack_source_upload')),
                ),
                DropdownMenuItem(
                  value: 'reference',
                  child: Text(widget.tx('knowledge.pack_source_reference')),
                ),
              ],
              onChanged: (value) =>
                  setState(() => _sourceMode = value ?? 'upload'),
            ),
            const SizedBox(height: 6),
            Text(switch (_sourceMode) {
              'reference' => widget.tx('knowledge.pack_source_reference_help'),
              _ => widget.tx('knowledge.pack_source_upload_help'),
            }, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            GroupedLabelPicker(
              selected: _selectedLabels,
              onChanged: (next) => setState(() => _selectedLabels = next),
              tx: widget.tx,
            ),
            Text(
              widget
                  .tx('knowledge.pack_files_ready')
                  .replaceAll('{{count}}', '${widget.files.length}'),
            ),
            if (widget.ignoredCount > 0) ...[
              const SizedBox(height: 4),
              Text(
                widget
                    .tx('knowledge.pack_files_ignored')
                    .replaceAll('{{count}}', '${widget.ignoredCount}'),
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            ],
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.files.length,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    widget.files[index].relativePath,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      SecondaryButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.tx('common.cancel')),
      ),
      PrimaryButton(
        onPressed: _submit,
        child: Text(widget.tx('knowledge.import_action')),
      ),
    ],
  );
}
