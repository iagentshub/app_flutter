part of '../pages/knowledge_page.dart';

class _SkillFormDialog extends StatefulWidget {
  const _SkillFormDialog({
    required this.tx,
    this.initial,
    this.allowPublic = true,
    this.requireQualityContent = false,
  });

  final String Function(String path, String fallback) tx;
  final Map<String, dynamic>? initial;
  final bool allowPublic;
  final bool requireQualityContent;

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
  Set<String> _selectedLanguageLabels = {};

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
            ? widget.tx('knowledge.new_skill_title', 'Nueva skill')
            : widget.tx('knowledge.edit_skill_title', 'Editar skill'),
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
                  labelText: widget.tx('knowledge.name_label', 'Nombre'),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? widget.tx('knowledge.name_required', 'Nombre obligatorio')
                    : null,
              ),
              const SizedBox(height: 10),
              if (widget.allowPublic)
                DropdownButtonFormField<String>(
                  initialValue: _scope,
                  decoration: InputDecoration(
                    labelText: widget.tx('knowledge.scope_label', 'Scope'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'private',
                      child: Text(
                        widget.tx('knowledge.scope_private', 'Privado'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'public',
                      child: Text(
                        widget.tx('knowledge.scope_public', 'Público'),
                      ),
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
                    labelText: widget.tx('knowledge.scope_label', 'Scope'),
                  ),
                  child: Text(
                    widget.tx(
                      'knowledge.scope_temp_session',
                      'Privado · temporal durante esta sesión',
                    ),
                  ),
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
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: widget.tx(
                    'knowledge.description_label',
                    'Descripción',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: widget.tx(
                    'knowledge.skill_category_label',
                    'Categoría',
                  ),
                ),
                items: [
                  for (final category in ['', ...kSkillCategories])
                    DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Icon(skillCategoryIcon(category), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              skillCategoryLabel(widget.tx, category),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _category = value);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contentController,
                minLines: 8,
                maxLines: 16,
                decoration: InputDecoration(
                  labelText: widget.tx(
                    'knowledge.skill_content_label',
                    'Contenido de la skill',
                  ),
                ),
                validator: (value) {
                  if (!widget.requireQualityContent) return null;
                  if (value == null || value.trim().length < 180) {
                    return widget.tx(
                      'knowledge.skill_quality_error',
                      'Añade instrucciones más completas (mínimo 180 caracteres)',
                    );
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
