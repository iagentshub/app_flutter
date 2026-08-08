import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../models/memory/memory_models.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/app_services_scope.dart';
import '../../../shared/state/async_section.dart';
import '../../../shared/widgets/async_section_builder.dart';
import '../../../shared/widgets/async_state_panel.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/resource_toolbar.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../shared/widgets/responsive_masonry_grid.dart';
import '../../../shared/widgets/state_messaging_mixin.dart';
import '../cards/memory_file_card.dart';
import '../repositories/memory_repository.dart';

part '../dialogs/memory_editor_dialog.dart';

class MemoryPage extends StatefulWidget {
  const MemoryPage({super.key});

  @override
  State<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends State<MemoryPage> with StateMessaging {
  /// Servicios globales (cliente HTTP, sesión, idioma): los aporta el
  /// AppServicesScope montado en App, no el router.
  late final _services = AppServicesScope.of(context);

  late final MemoryRepository _repository;
  late final TranslatedTexts _t;

  /// Cargando / error / datos con la política en un solo sitio (ver
  /// [AsyncSection]): al fallar una recarga se conserva lo ya cargado.
  late final AsyncSection<List<MemoryFileItem>> _section;

  List<MemoryFileItem> get _files => _section.data ?? const [];

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  @override
  void initState() {
    super.initState();
    _repository = MemoryRepository(apiClient: _services.apiClient);
    _t = TranslatedTexts(
      localeController: _services.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _section = AsyncSection<List<MemoryFileItem>>(
      fetch: _fetchFiles,
      genericError: () =>
          _tx('memory.error_generic', 'No se pudo cargar Memory'),
    );
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _section.dispose();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => _services.sessionController.gaToken;

  Future<void> _load() => _section.load();

  Future<List<MemoryFileItem>> _fetchFiles() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw ApiError(
        statusCode: 401,
        message: _tx('common.no_session', 'No hay sesión activa'),
      );
    }
    return _repository.listFiles(token);
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
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('memory.load_file_error', 'No se pudo cargar el archivo'),
        isError: true,
      );
    }
  }

  Future<void> _saveFile(String filename, String content) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    if (filename.trim().isEmpty) {
      showMessage(
        _tx('memory.filename_required', 'Nombre de archivo obligatorio'),
        isError: true,
      );
      return;
    }

    var normalized = filename.trim();
    if (!normalized.endsWith('.md')) normalized = '$normalized.md';

    try {
      await _repository.saveFile(token, normalized, content);
      showMessage(_tx('memory.save_success', 'Archivo guardado'));
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('memory.save_error', 'No se pudo guardar el archivo'),
        isError: true,
      );
    }
  }

  Future<void> _deleteFile(MemoryFileItem file) async {
    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('memory.delete_dialog_title', 'Eliminar archivo'),
      message: _tx(
        'memory.delete_dialog_body',
        '¿Seguro que quieres eliminar "{{filename}}"?',
      ).replaceAll('{{filename}}', file.filename),
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      confirmLabel: _tx('common.delete', 'Eliminar'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteFile(token, file.filename);
      showMessage(_tx('memory.delete_success', 'Archivo eliminado'));
      await _load();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('memory.delete_error', 'No se pudo eliminar el archivo'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AsyncSectionBuilder<List<MemoryFileItem>>(
      section: _section,
      retryLabel: _tx('common.retry', 'Reintentar'),
      builder: (context, _) => _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    final toolbar = ResourceToolbar(
      actions: [
        AppIconButton.filled(
          onPressed: _createFile,
          icon: const Icon(Icons.add),
          tooltip: _tx('memory.new_file_tooltip', 'Nuevo archivo'),
        ),
        AppIconButton.outlined(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          tooltip: _tx('memory.refresh_tooltip', 'Actualizar'),
        ),
      ],
      summary: Text(
        '${_tx('memory.files_count', 'Archivos')}: ${_files.length}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
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
                child: AsyncStatePanel.empty(
                  padding: EdgeInsets.zero,
                  icon: Icons.description_outlined,
                  title: _tx('memory.empty_title', 'Sin archivos de memoria'),
                  message: _tx(
                    'memory.empty_files',
                    'La memoria guarda lo que tus agentes deben recordar entre '
                        'conversaciones.',
                  ),
                  actionLabel: _tx('memory.empty_action', 'Crear el primero'),
                  onAction: _createFile,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: ResponsiveSliverMasonryGrid(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return MemoryFileCard(
                    file: file,
                    sizeLabel: _tx('memory.size_label', 'Tamaño'),
                    editTooltip: _tx('common.edit', 'Editar'),
                    deleteTooltip: _tx('common.delete', 'Eliminar'),
                    onEdit: () => _editFile(file),
                    onDelete: () => _deleteFile(file),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
