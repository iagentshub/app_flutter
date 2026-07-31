part of '../pages/memory_page.dart';

class _MemoryEditorDialog extends StatefulWidget {
  const _MemoryEditorDialog({
    required this.tx,
    this.initialFilename,
    this.initialContent,
    this.lockFilename = false,
  });

  final String Function(String path, String fallback) tx;
  final String? initialFilename;
  final String? initialContent;
  final bool lockFilename;

  @override
  State<_MemoryEditorDialog> createState() => _MemoryEditorDialogState();
}

class _MemoryEditorDialogState extends State<_MemoryEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _filenameController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();
    _filenameController = TextEditingController(
      text: widget.initialFilename ?? 'notes.md',
    );
    _contentController = TextEditingController(
      text: widget.initialContent ?? '',
    );
  }

  @override
  void dispose() {
    _filenameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'filename': _filenameController.text.trim(),
      'content': _contentController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initialFilename == null
            ? widget.tx('memory.new_dialog_title', 'Nuevo archivo de memoria')
            : widget.tx('memory.edit_dialog_title', 'Editar archivo'),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 760),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _filenameController,
                readOnly: widget.lockFilename,
                decoration: InputDecoration(
                  labelText: widget.tx(
                    'memory.filename_label',
                    'Nombre de archivo (.md)',
                  ),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) {
                    return widget.tx(
                      'memory.filename_validator',
                      'Nombre obligatorio',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 10,
                maxLines: 18,
                decoration: InputDecoration(
                  labelText: widget.tx('memory.content_label', 'Contenido'),
                ),
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
