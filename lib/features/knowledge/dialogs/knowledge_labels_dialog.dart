part of '../pages/knowledge_page.dart';

class _KnowledgeEditResult {
  const _KnowledgeEditResult({
    required this.name,
    required this.labels,
    this.description,
  });

  final String name;
  final String? description;
  final Set<String> labels;
}

Future<_KnowledgeEditResult?> _showKnowledgeEditDialog(
  BuildContext context, {
  required String initialName,
  required Set<String> initialLabels,
  required String Function(String path, String fallback) tx,
  required bool isPack,
  String initialDescription = '',
  List<LabelGroupDef> groups = kLabelGroups,
}) {
  return showDialog<_KnowledgeEditResult>(
    context: context,
    builder: (context) => _KnowledgeEditDialog(
      initialName: initialName,
      initialDescription: initialDescription,
      initialLabels: initialLabels,
      isPack: isPack,
      tx: tx,
      groups: groups,
    ),
  );
}

class _KnowledgeEditDialog extends StatefulWidget {
  const _KnowledgeEditDialog({
    required this.initialName,
    required this.initialDescription,
    required this.initialLabels,
    required this.isPack,
    required this.tx,
    required this.groups,
  });

  final String initialName;
  final String initialDescription;
  final Set<String> initialLabels;
  final bool isPack;
  final String Function(String path, String fallback) tx;
  final List<LabelGroupDef> groups;

  @override
  State<_KnowledgeEditDialog> createState() => _KnowledgeEditDialogState();
}

class _KnowledgeEditDialogState extends State<_KnowledgeEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Set<String> _labels;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
    _labels = Set<String>.of(widget.initialLabels);
    if (!_labels.contains('private') && !_labels.contains('public')) {
      _labels.add('private');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _KnowledgeEditResult(
        name: _nameController.text.trim(),
        description: widget.isPack ? _descriptionController.text.trim() : null,
        labels: _labels,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isPack
            ? widget.tx('knowledge.edit_pack_title', 'Editar pack')
            : widget.tx('knowledge.edit_item_title', 'Editar archivo'),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 520),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _nameController,
                maxLength: 160,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: widget.tx('knowledge.name_label', 'Nombre'),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? widget.tx(
                        'knowledge.name_required',
                        'El nombre es obligatorio',
                      )
                    : null,
              ),
              if (widget.isPack) ...[
                const SizedBox(height: 4),
                TextFormField(
                  controller: _descriptionController,
                  maxLength: 2000,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: widget.tx(
                      'knowledge.description_label',
                      'Descripción',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              GroupedLabelPicker(
                selected: _labels,
                onChanged: (next) => setState(() => _labels = next),
                tx: widget.tx,
                groups: widget.groups,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: _save,
          child: Text(widget.tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}
