part of '../pages/knowledge_page.dart';

/// Mismo límite que el backend (`tools.py::_MAX_TOOL_BINARY_BYTES`) —
/// comprobación en cliente para no hacer esperar una subida que el servidor
/// va a rechazar de todas formas.
const int _maxToolBinaryBytes = 50 * 1024 * 1024;

class _ToolFormDialog extends StatefulWidget {
  const _ToolFormDialog({required this.tx, this.initial});

  final String Function(String path, String fallback) tx;
  final Map<String, dynamic>? initial;

  @override
  State<_ToolFormDialog> createState() => _ToolFormDialogState();
}

class _ToolFormDialogState extends State<_ToolFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _contentController;
  String _language = 'python';
  Set<String> _selectedLabels = {};

  String? _existingBinaryFilename;
  int? _existingBinarySize;
  String? _pickedFileName;
  List<int>? _pickedBytes;
  String? _binaryError;

  bool get _isNew => widget.initial == null;

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  /// La visibilidad no es un campo aparte: es la label "private"/"public"
  /// del grupo excluyente de Visibilidad (misma fuente única de verdad que
  /// `agent_form_dialog.dart`).
  String get _scope =>
      _selectedLabels.contains('public') ? 'public' : 'private';

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
    _contentController = TextEditingController(
      text: initial?['content']?.toString() ?? '',
    );
    _language = (initial?['language'] as String?) ?? 'python';
    _existingBinaryFilename = initial?['binary_filename']?.toString();
    final existingSize = initial?['binary_size'];
    _existingBinarySize = existingSize is num ? existingSize.toInt() : null;

    final labelsRaw = initial?['labels'];
    _selectedLabels = labelsRaw is List
        ? labelsRaw.map((e) => e.toString()).toSet()
        : {'private'};
    if (!_selectedLabels.contains('private') &&
        !_selectedLabels.contains('public')) {
      _selectedLabels = {..._selectedLabels, 'private'};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _selectLanguage(String language) {
    setState(() {
      final wasCpp = _language == 'cpp';
      _language = language;
      // Sugerencia editable (no forzada): marcar "review" al pasar a cpp en
      // una tool nueva, nunca al editar una ya existente ni en selecciones
      // repetidas del mismo chip.
      if (language == 'cpp' && !wasCpp && _isNew) {
        _selectedLabels = {..._selectedLabels, 'review'};
      }
      _binaryError = null;
    });
  }

  Future<void> _pickBinary() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _binaryError = _tx(
          'knowledge.binary_read_error',
          'No se pudieron leer los bytes del fichero',
        );
      });
      return;
    }
    if (bytes.length > _maxToolBinaryBytes) {
      setState(() {
        _binaryError = _tx(
          'knowledge.binary_too_large',
          'El binario no puede superar 50 MB',
        );
      });
      return;
    }
    setState(() {
      _pickedFileName = file.name;
      _pickedBytes = bytes;
      _binaryError = null;
    });
  }

  bool get _hasAnyBinary =>
      _pickedFileName != null || (_existingBinaryFilename ?? '').isNotEmpty;

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_language == 'cpp' && !_hasAnyBinary) {
      setState(() {
        _binaryError = _tx(
          'knowledge.binary_required',
          'Selecciona un binario para esta herramienta antes de guardar',
        );
      });
      return;
    }

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'language': _language,
      'labels': _selectedLabels.toList(),
      'scope': _scope,
    };
    if (_language != 'cpp') {
      payload['content'] = _contentController.text.trim();
    }
    if (widget.initial?['id'] != null) payload['id'] = widget.initial!['id'];
    if (_pickedFileName != null && _pickedBytes != null) {
      // Claves reservadas, nunca enviadas tal cual al backend: el
      // controlador (`_saveTool`) las extrae para el segundo paso
      // (`uploadToolBinary`) antes de mandar el JSON de metadatos.
      payload['__binaryFileName'] = _pickedFileName;
      payload['__binaryBytes'] = _pickedBytes;
    }
    Navigator.of(context).pop(payload);
  }

  Widget _buildLanguageChip(String language) {
    final selected = _language == language;
    return ChoiceChip(
      avatar: Icon(toolLanguageIcon(language), size: 16),
      label: Text(toolLanguageLabel(_tx, language)),
      selected: selected,
      onSelected: (_) => _selectLanguage(language),
    );
  }

  Widget _buildBinarySection(BuildContext context) {
    final displayName = _pickedFileName ?? _existingBinaryFilename;
    final displaySize = _pickedFileName != null
        ? _pickedBytes?.length
        : _existingBinarySize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tx('knowledge.field_binary', 'Binario'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Text(
          (displayName != null && displayName.isNotEmpty)
              ? '$displayName · ${formatToolBinarySize(displaySize ?? 0)}'
              : _tx('knowledge.no_binary', 'Sin binario todavía'),
        ),
        const SizedBox(height: 8),
        SecondaryButton.icon(
          onPressed: _pickBinary,
          icon: const Icon(Icons.upload_file_outlined, size: 18),
          label: Text(
            _hasAnyBinary
                ? _tx('knowledge.replace_binary', 'Reemplazar binario')
                : _tx('knowledge.upload_binary', 'Subir binario'),
          ),
        ),
        if (_binaryError != null) ...[
          const SizedBox(height: 6),
          Text(
            _binaryError!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? _tx('knowledge.new_tool_title', 'Nueva herramienta')
            : _tx('knowledge.edit_tool_title', 'Editar herramienta'),
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
                controller: _descriptionController,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: _tx('agents.field_description', 'Descripción'),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _tx('agents.field_labels', 'Etiquetas'),
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              GroupedLabelPicker(
                selected: _selectedLabels,
                onChanged: (next) => setState(() => _selectedLabels = next),
                tx: widget.tx,
              ),
              Text(
                _tx('knowledge.field_language', 'Lenguaje'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildLanguageChip('python'),
                  _buildLanguageChip('shell'),
                  _buildLanguageChip('cpp'),
                ],
              ),
              const SizedBox(height: 10),
              if (_language == 'cpp')
                _buildBinarySection(context)
              else
                TextFormField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: 16,
                  decoration: InputDecoration(
                    labelText: _tx(
                      'knowledge.field_tool_content',
                      'Contenido de la herramienta',
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
