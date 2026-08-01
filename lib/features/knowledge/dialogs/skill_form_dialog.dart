part of '../pages/knowledge_page.dart';

class _SkillFormDialog extends StatefulWidget {
  const _SkillFormDialog({this.initial, this.allowPublic = true});

  final Map<String, dynamic>? initial;
  final bool allowPublic;

  @override
  State<_SkillFormDialog> createState() => _SkillFormDialogState();
}

class _SkillFormDialogState extends State<_SkillFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _contentController;
  String _scope = 'private';
  String _category = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(
      text: initial?['name']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: initial?['description']?.toString() ?? '',
    );
    _category = initial?['category']?.toString() ?? '';
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
    _descriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'category': _category,
      'content': _contentController.text.trim(),
      'scope': _scope,
    };
    if (widget.initial?['id'] != null) payload['id'] = widget.initial!['id'];
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? 'Nueva skill' : 'Editar skill'),
      content: SizedBox(
        width: dialogContentWidth(context, 620),
        child: Form(
          key: _formKey,
          child: ListView(
            shrinkWrap: true,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Nombre obligatorio'
                    : null,
              ),
              const SizedBox(height: 10),
              if (widget.allowPublic)
                DropdownButtonFormField<String>(
                  initialValue: _scope,
                  decoration: const InputDecoration(labelText: 'Scope'),
                  items: const [
                    DropdownMenuItem(value: 'private', child: Text('private')),
                    DropdownMenuItem(value: 'public', child: Text('public')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _scope = value);
                  },
                )
              else
                const InputDecorator(
                  decoration: InputDecoration(labelText: 'Scope'),
                  child: Text('private · temporal durante esta sesión'),
                ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Descripción'),
              ),
              const SizedBox(height: 10),
              Text(
                'Categoría (define el icono)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ChoiceChip(
                    avatar: Icon(skillCategoryIcon(''), size: 16),
                    label: Text(skillCategoryLabel('')),
                    selected: _category.isEmpty,
                    onSelected: (_) => setState(() => _category = ''),
                  ),
                  for (final category in kSkillCategories)
                    ChoiceChip(
                      avatar: Icon(skillCategoryIcon(category), size: 16),
                      label: Text(skillCategoryLabel(category)),
                      selected: _category == category,
                      onSelected: (_) => setState(() => _category = category),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 8,
                maxLines: 16,
                decoration: const InputDecoration(
                  labelText: 'Contenido de la skill',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TertiaryButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        PrimaryButton(onPressed: _submit, child: const Text('Guardar')),
      ],
    );
  }
}
