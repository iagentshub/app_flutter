part of '../pages/knowledge_page.dart';

class _AddTextDialog extends StatefulWidget {
  const _AddTextDialog({required this.tx});

  final String Function(String path, String fallback) tx;

  @override
  State<_AddTextDialog> createState() => _AddTextDialogState();
}

class _AddTextDialogState extends State<_AddTextDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sourceController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _sourceController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'title': _titleController.text.trim(),
      'source': _sourceController.text.trim(),
      'content': _contentController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tx('knowledge.add_text_title', 'Añadir texto')),
      content: SizedBox(
        width: dialogContentWidth(context, 620),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Título obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _sourceController,
                decoration: const InputDecoration(
                  labelText: 'Fuente (opcional)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 6,
                maxLines: 12,
                decoration: const InputDecoration(labelText: 'Contenido'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Contenido obligatorio';
                  }
                  return null;
                },
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
          onPressed: _submit,
          child: Text(widget.tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}
