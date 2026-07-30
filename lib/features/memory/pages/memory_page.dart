import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../models/memory/memory_models.dart';
import '../repositories/memory_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/action_icon_button.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({
    required this.apiClient,
    required this.sessionController,
    required this.localeController,
    super.key,
  });

  final ApiClient apiClient;
  final SessionController sessionController;
  final LocaleController localeController;

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> {
  late final MemoryRepository _repository;
  late final TranslatedTexts _t;
  List<MemoryFileItem> _files = const [];
  bool _loading = true;
  String? _error;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = MemoryRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final files = await _repository.listFiles(token);
      if (!mounted) return;
      setState(() {
        _files = files;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx('memory.error_generic', 'No se pudo cargar Memory');
        _loading = false;
      });
    }
  }

  Future<void> _createFile() async {
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => _MemoryEditorDialog(tx: _tx),
    );
    if (payload == null) return;
    await _saveFile(payload['filename'] ?? '', payload['content'] ?? '');
  }

  Future<void> _editFile(MemoryFileItem file) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      final content = await _repository.getFileContent(token, file.filename);
      if (!mounted) return;
      final payload = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => _MemoryEditorDialog(
          tx: _tx,
          initialFilename: file.filename,
          initialContent: content,
          lockFilename: true,
        ),
      );
      if (payload == null) return;
      await _saveFile(file.filename, payload['content'] ?? '');
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('memory.load_file_error', 'No se pudo cargar el archivo'),
        isError: true,
      );
    }
  }

  Future<void> _saveFile(String filename, String content) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    if (filename.trim().isEmpty) {
      _showMessage(
        _tx('memory.filename_required', 'Nombre de archivo obligatorio'),
        isError: true,
      );
      return;
    }

    var normalized = filename.trim();
    if (!normalized.endsWith('.md')) normalized = '$normalized.md';

    try {
      await _repository.saveFile(token, normalized, content);
      _showMessage(_tx('memory.save_success', 'Archivo guardado'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('memory.save_error', 'No se pudo guardar el archivo'),
        isError: true,
      );
    }
  }

  Future<void> _deleteFile(MemoryFileItem file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_tx('memory.delete_dialog_title', 'Eliminar archivo')),
        content: Text(
          _tx(
            'memory.delete_dialog_body',
            '¿Seguro que quieres eliminar "{{filename}}"?',
          ).replaceAll('{{filename}}', file.filename),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_tx('common.cancel', 'Cancelar')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_tx('common.delete', 'Eliminar')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteFile(token, file.filename);
      _showMessage(_tx('memory.delete_success', 'Archivo eliminado'));
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('memory.delete_error', 'No se pudo eliminar el archivo'),
        isError: true,
      );
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tx('memory.error_loading_title', 'Error cargando Memory'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: Text(_tx('common.retry', 'Reintentar')),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final toolbar = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            IconButton.filled(
              onPressed: _createFile,
              icon: const Icon(Icons.add),
              tooltip: _tx('memory.new_file_tooltip', 'Nuevo archivo'),
            ),
            IconButton.outlined(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              tooltip: _tx('memory.refresh_tooltip', 'Actualizar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${_tx('memory.files_count', 'Archivos')}: ${_files.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(child: toolbar),
          ),
          if (_files.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _tx(
                        'memory.empty_files',
                        'No hay archivos de memoria. Crea el primero.',
                      ),
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: _files.length,
                itemBuilder: (context, index) => _buildFileCard(_files[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileCard(MemoryFileItem file) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              file.filename,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              '${_tx('memory.size_label', 'Tamaño')}: ${file.size} chars${file.updatedAt.isEmpty ? '' : ' · ${file.updatedAt}'}',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: _tx('common.edit', 'Editar'),
                  onPressed: () => _editFile(file),
                ),
                ActionIconButton(
                  icon: Icons.delete_outline,
                  tooltip: _tx('common.delete', 'Eliminar'),
                  danger: true,
                  onPressed: () => _deleteFile(file),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.tx('common.save', 'Guardar')),
        ),
      ],
    );
  }
}
