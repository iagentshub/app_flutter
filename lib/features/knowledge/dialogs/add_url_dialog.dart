part of '../pages/knowledge_page.dart';

class _AddUrlDialog extends StatefulWidget {
  const _AddUrlDialog({required this.tx});

  final String Function(String path) tx;

  @override
  State<_AddUrlDialog> createState() => _AddUrlDialogState();
}

class _AddUrlDialogState extends State<_AddUrlDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  Set<String> _selectedLabels = {'private'};

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'url': _urlController.text.trim(),
      'title': _titleController.text.trim(),
      'labels': _selectedLabels.toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('knowledge.import_url_title')),
      content: SizedBox(
        width: dialogContentWidth(context, 620),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: InputDecoration(
                  labelText: widget.tx('knowledge.url_label'),
                ),
                validator: (value) {
                  final raw = value?.trim() ?? '';
                  if (raw.isEmpty) {
                    return widget.tx('knowledge.url_required');
                  }
                  final uri = Uri.tryParse(raw);
                  if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                    return widget.tx('knowledge.url_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              GroupedLabelPicker(
                selected: _selectedLabels,
                onChanged: (next) => setState(() => _selectedLabels = next),
                tx: widget.tx,
              ),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: widget.tx('knowledge.optional_title'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
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
}
