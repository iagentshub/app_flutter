part of '../pages/knowledge_page.dart';

/// Regex del backend para el alias invocable (`app/api/routes/prompts.py`):
/// minúsculas/dígitos, `-`/`_` en el medio, 3-30 caracteres en total.
final RegExp _promptAliasPattern = RegExp(
  r'^[a-z0-9][a-z0-9_-]{1,28}[a-z0-9]$',
);

class _PromptFormDialog extends StatefulWidget {
  const _PromptFormDialog({
    required this.tx,
    this.initial,
    this.allowPublic = true,
  });

  final String Function(String path, String fallback) tx;
  final Map<String, dynamic>? initial;
  final bool allowPublic;

  @override
  State<_PromptFormDialog> createState() => _PromptFormDialogState();
}

class _PromptFormDialogState extends State<_PromptFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _aliasController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _contentController;
  String _scope = 'private';

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(
      text: initial?['name']?.toString() ?? '',
    );
    _aliasController = TextEditingController(
      text: initial?['alias']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: initial?['description']?.toString() ?? '',
    );
    _contentController = TextEditingController(
      text: initial?['content']?.toString() ?? '',
    );
    _scope = widget.allowPublic
        ? ((initial?['scope'] as String?) ?? 'private')
        : 'private';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aliasController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'alias': _aliasController.text.trim().toLowerCase(),
      'description': _descriptionController.text.trim(),
      'content': _contentController.text.trim(),
      'scope': _scope,
    };
    if (widget.initial?['id'] != null) payload['id'] = widget.initial!['id'];
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? _tx('knowledge.new_prompt_title', 'Nuevo prompt')
            : _tx('knowledge.edit_prompt_title', 'Editar prompt'),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 620),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: _tx('agents.field_name', 'Nombre'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? _tx('agents.name_required', 'El nombre es obligatorio')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _aliasController,
                decoration: InputDecoration(
                  labelText: _tx('knowledge.field_alias', 'Alias'),
                  prefixText: '@',
                  helperText: _tx(
                    'knowledge.alias_hint',
                    'Minúsculas, números, "-" o "_" (3-30 caracteres). '
                        'Se usa como @alias para invocarlo en el chat.',
                  ),
                  helperMaxLines: 2,
                ),
                onChanged: (value) {
                  final lower = value.toLowerCase();
                  if (lower == value) return;
                  _aliasController.value = _aliasController.value.copyWith(
                    text: lower,
                    selection: TextSelection.collapsed(offset: lower.length),
                  );
                },
                validator: (value) {
                  final normalized = (value ?? '').trim().toLowerCase();
                  if (normalized.isEmpty) {
                    return _tx(
                      'knowledge.alias_required',
                      'El alias es obligatorio',
                    );
                  }
                  if (!_promptAliasPattern.hasMatch(normalized)) {
                    return _tx(
                      'knowledge.alias_invalid',
                      'Usa minúsculas, números, "-" o "_" (3-30 caracteres)',
                    );
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              if (widget.allowPublic)
                DropdownButtonFormField<String>(
                  initialValue: _scope,
                  decoration: InputDecoration(
                    labelText: _tx('agents.scope_label', 'Visibilidad'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'private',
                      child: Text(_tx('agents.scope_private', 'Privado')),
                    ),
                    DropdownMenuItem(
                      value: 'public',
                      child: Text(_tx('agents.scope_public', 'Público')),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _scope = value);
                  },
                )
              else
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: _tx('agents.scope_label', 'Visibilidad'),
                  ),
                  child: Text(
                    _tx(
                      'knowledge.scope_temp_session',
                      'private · temporal durante esta sesión',
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _tx('agents.field_description', 'Descripción'),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 8,
                maxLines: 16,
                decoration: InputDecoration(
                  labelText: _tx(
                    'knowledge.field_prompt_content',
                    'Contenido del prompt',
                  ),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? _tx(
                        'knowledge.content_required',
                        'El contenido es obligatorio',
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tx('common.cancel', 'Cancelar')),
        ),
        PrimaryButton(
          onPressed: _submit,
          child: Text(_tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}
