part of '../pages/knowledge_page.dart';

class _ToolFormDialog extends StatefulWidget {
  const _ToolFormDialog({required this.tx, this.initial});

  final String Function(String path) tx;
  final Map<String, dynamic>? initial;

  @override
  State<_ToolFormDialog> createState() => _ToolFormDialogState();
}

class _ToolFormDialogState extends State<_ToolFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _contentController;
  ToolLanguage _language = ToolLanguage.python;
  String _targetOs = '';
  String _targetArch = '';
  Set<String> _selectedLabels = {};

  String? _existingBinaryFilename;
  int? _existingBinarySize;
  String? _pickedFileName;
  int? _pickedFileSize;
  Stream<List<int>> Function()? _pickedStream;
  String? _fileError;
  bool _dragHighlight = false;

  bool get _isNew => widget.initial == null;

  String _tx(String path) => widget.tx(path);

  /// La visibilidad no es un campo aparte: es la label "private"/"public"
  /// del grupo excluyente de Visibilidad (misma fuente única de verdad que
  /// `agent_form_page.dart`).
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
    _instructionsController = TextEditingController(
      text: initial?['instructions']?.toString() ?? '',
    );
    _contentController = TextEditingController(
      text: initial?['content']?.toString() ?? '',
    );
    _language =
        ToolLanguage.tryParseSupported(initial?['language']) ??
        ToolLanguage.python;
    _targetOs = initial?['target_os']?.toString() ?? '';
    _targetArch = initial?['target_arch']?.toString() ?? '';
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
    _instructionsController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _selectLanguage(ToolLanguage language) {
    setState(() {
      final wasBinary = _language.requiresBinary;
      _language = language;
      // Sugerencia editable (no forzada): marcar "review" al pasar a cpp en
      // una tool nueva, nunca al editar una ya existente ni en selecciones
      // repetidas del mismo chip.
      if (language.requiresBinary && !wasBinary && _isNew) {
        _selectedLabels = {..._selectedLabels, 'review'};
      }
      _fileError = null;
    });
  }

  String get _scriptExtension =>
      ToolRuntimeCatalog.scriptExtension(_language) ?? 'py';

  Future<void> _pickFile() async {
    final result = _language.requiresBinary
        ? await FilePicker.pickFiles(withReadStream: true)
        : await FilePicker.pickFiles(
            withReadStream: true,
            type: FileType.custom,
            allowedExtensions: [_scriptExtension],
          );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    await _handlePickedFile(
      file.name,
      file.size,
      () => file.readStream ?? file.xFile.openRead(),
    );
  }

  /// Selector y drag/drop llegan al mismo camino y conservan el binario como
  /// flujo hasta que se envía. Los scripts sí se leen para editar su texto.
  Future<void> _handlePickedFile(
    String fileName,
    int declaredSize,
    Stream<List<int>> Function() openRead,
  ) async {
    final safeFileName = fileName.trim().isEmpty ? 'binary.bin' : fileName;
    if (declaredSize <= 0) {
      setState(() {
        _fileError = _tx('knowledge.binary_read_error');
      });
      return;
    }
    if (UploadLimits.exceeds(declaredSize)) {
      setState(() {
        _fileError = _tx('knowledge.binary_too_large')
            .replaceAll('{limit}', UploadLimits.formatted);
      });
      return;
    }
    if (_language.requiresBinary) {
      setState(() {
        _pickedFileName = safeFileName;
        _pickedFileSize = declaredSize;
        _pickedStream = openRead;
        _fileError = null;
      });
      return;
    }
    // python/shell: el contenido es texto — se decodifica y se vuelca en el
    // mismo controller que ya usa el textarea manual, nunca se sube como
    // binario (_pickedStream se queda a propósito sin tocar).
    try {
      final bytes = BytesBuilder(copy: false);
      var actualSize = 0;
      await for (final chunk in openRead()) {
        actualSize += chunk.length;
        if (UploadLimits.exceeds(actualSize)) {
          setState(() {
            _fileError = _tx('knowledge.binary_too_large')
                .replaceAll('{limit}', UploadLimits.formatted);
          });
          return;
        }
        bytes.add(chunk);
      }
      final text = utf8.decode(bytes.takeBytes());
      if (!mounted) return;
      setState(() {
        _contentController.text = text;
        _pickedFileName = safeFileName;
        _pickedFileSize = actualSize;
        _pickedStream = null;
        _fileError = null;
      });
    } on FormatException {
      setState(() {
        _fileError = _tx('knowledge.script_decode_error');
      });
    } catch (_) {
      setState(() {
        _fileError = _tx('knowledge.binary_read_error');
      });
    }
  }

  bool get _hasAnyBinary =>
      _pickedFileName != null || (_existingBinaryFilename ?? '').isNotEmpty;

  void _submit() {
    if (_language.requiresBinary && !_hasAnyBinary) {
      setState(() {
        _fileError = _tx('knowledge.binary_required');
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descriptionController.text.trim(),
      'instructions': _instructionsController.text.trim(),
      'language': _language.apiValue,
      'labels': _selectedLabels.toList(),
      'scope': _scope,
    };
    if (!_language.requiresBinary) {
      payload['content'] = _contentController.text.trim();
    } else {
      payload['target_os'] = _targetOs;
      payload['target_arch'] = _targetArch;
    }
    if (widget.initial?['id'] != null) payload['id'] = widget.initial!['id'];
    PendingToolArtifact? artifact;
    if (_language.requiresBinary &&
        _pickedFileName != null &&
        _pickedStream != null &&
        _pickedFileSize != null) {
      artifact = PendingToolArtifact(
        fileName: _pickedFileName!,
        size: _pickedFileSize!,
        openRead: _pickedStream!,
      );
    }
    Navigator.of(context)
        .pop(ToolFormResult(payload: payload, artifact: artifact));
  }

  Widget _buildFileDropZone(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = _pickedFileName ?? _existingBinaryFilename;
    final displaySize = _pickedFileName != null
        ? _pickedFileSize
        : _existingBinarySize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropTarget(
          onDragEntered: (_) => setState(() => _dragHighlight = true),
          onDragExited: (_) => setState(() => _dragHighlight = false),
          onDragDone: (details) async {
            setState(() => _dragHighlight = false);
            if (details.files.isEmpty) return;
            final dropped = details.files.first;
            await _handlePickedFile(
              dropped.name,
              await dropped.length(),
              dropped.openRead,
            );
          },
          child: InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _dragHighlight
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: _dragHighlight ? 2 : 1,
                ),
                color: _dragHighlight
                    ? theme.colorScheme.primary.withValues(alpha: 0.06)
                    : null,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.upload_file_outlined,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _tx('knowledge.drop_hint_file'),
                    textAlign: TextAlign.center,
                  ),
                  if (!_language.requiresBinary) ...[
                    const SizedBox(height: 4),
                    Text(
                      _tx('knowledge.drop_hint_extension')
                          .replaceAll('{{ext}}', _scriptExtension),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (displayName != null && displayName.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '$displayName · ${formatFileSize(displaySize ?? 0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_fileError != null) ...[
          const SizedBox(height: 6),
          Text(_fileError!, style: TextStyle(color: theme.colorScheme.error)),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.initial == null
            ? _tx('knowledge.new_tool_title')
            : _tx('knowledge.edit_tool_title'),
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
                controller: _instructionsController,
                minLines: 3,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: _tx('knowledge.field_tool_instructions'),
                ),
              ),
              const SizedBox(height: 10),
              GroupedLabelPicker(
                selected: _selectedLabels,
                onChanged: (next) => setState(() => _selectedLabels = next),
                tx: widget.tx,
                groups: kOperationalLabelGroups,
              ),
              DropdownButtonFormField<ToolLanguage>(
                initialValue: _language,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _tx('knowledge.field_language'),
                ),
                items: [
                  for (final language in ToolRuntimeCatalog.supported)
                    DropdownMenuItem(
                      value: language,
                      child: Row(
                        children: [
                          Icon(language.icon, size: 16),
                          const SizedBox(width: 8),
                          Text(language.label(_tx)),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) _selectLanguage(value);
                },
              ),
              const SizedBox(height: 10),
              _buildFileDropZone(context),
              if (_language.requiresBinary) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _targetOs.isEmpty ? null : _targetOs,
                  decoration: InputDecoration(
                    labelText: _tx('knowledge.field_target_os'),
                  ),
                  items: [
                    for (final value
                        in ToolRuntimeCatalog.targetOperatingSystems)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_tx('tools.target_os_$value')),
                      ),
                  ],
                  validator: (value) => value == null || value.isEmpty
                      ? _tx('knowledge.target_required')
                      : null,
                  onChanged: (value) => setState(() => _targetOs = value ?? ''),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _targetArch.isEmpty ? null : _targetArch,
                  decoration: InputDecoration(
                    labelText: _tx('knowledge.field_target_arch'),
                  ),
                  items: [
                    for (final value in ToolRuntimeCatalog.targetArchitectures)
                      DropdownMenuItem(
                        value: value,
                        child: Text(_tx('tools.target_arch_$value')),
                      ),
                  ],
                  validator: (value) => value == null || value.isEmpty
                      ? _tx('knowledge.target_required')
                      : null,
                  onChanged: (value) =>
                      setState(() => _targetArch = value ?? ''),
                ),
              ],
              if (!_language.requiresBinary) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _contentController,
                  minLines: 8,
                  maxLines: 16,
                  decoration: InputDecoration(
                    labelText: _tx('knowledge.field_tool_content'),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? _tx('knowledge.content_required')
                      : null,
                ),
              ],
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
