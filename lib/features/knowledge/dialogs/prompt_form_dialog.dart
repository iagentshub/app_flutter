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

  final String Function(String path) tx;
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
  Set<String> _selectedLanguageLabels = {};

  String _tx(String path) => widget.tx(path);

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
    final labels = initial?['labels'];
    if (labels is List) {
      _selectedLanguageLabels = labels
          .map((value) => value.toString())
          .where(isLanguageLabel)
          .toSet();
    }
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
      'labels': contentLabelsForScope(_scope, _selectedLanguageLabels),
    };
    if (widget.initial?['id'] != null) payload['id'] = widget.initial!['id'];
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? _tx('knowledge.new_prompt_title')
            : _tx('knowledge.edit_prompt_title'),
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
                  labelText: _tx('agents.field_name'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? _tx('agents.name_required')
                    : null,
              ),
              const SizedBox(height: 10),
              GroupedLabelPicker(
                selected: _selectedLanguageLabels,
                onChanged: (next) =>
                    setState(() => _selectedLanguageLabels = next),
                tx: widget.tx,
                groups: const [kLanguageLabelGroup],
              ),
              TextFormField(
                controller: _aliasController,
                decoration: InputDecoration(
                  labelText: _tx('knowledge.field_alias'),
                  prefixText: '@',
                  helperText: _tx('knowledge.alias_hint'),
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
                    return _tx('knowledge.alias_required');
                  }
                  if (!_promptAliasPattern.hasMatch(normalized)) {
                    return _tx('knowledge.alias_invalid');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              if (widget.allowPublic)
                DropdownButtonFormField<String>(
                  initialValue: _scope,
                  decoration: InputDecoration(
                    labelText: _tx('agents.scope_label'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'private',
                      child: Text(_tx('agents.scope_private')),
                    ),
                    DropdownMenuItem(
                      value: 'public',
                      child: Text(_tx('agents.scope_public')),
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
                    labelText: _tx('agents.scope_label'),
                  ),
                  child: Text(_tx('knowledge.scope_temp_session')),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _tx('agents.field_description'),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 8,
                maxLines: 16,
                decoration: InputDecoration(
                  labelText: _tx('knowledge.field_prompt_content'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? _tx('knowledge.content_required')
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tx('common.cancel')),
        ),
        PrimaryButton(onPressed: _submit, child: Text(_tx('common.save'))),
      ],
    );
  }
}
