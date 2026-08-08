part of '../pages/knowledge_page.dart';

/// Acciones CRUD de Tools: calco de `_KnowledgeActions` para skills,
/// separado en su propio fichero para no hacer crecer sin límite
/// `knowledge_actions.dart` (ver `feature_architecture_test.dart`).
extension _ToolActions on _KnowledgePageState {
  Future<void> _loadTools() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      refresh(() {
        _toolsError = _tx('common.no_session', 'No hay sesión activa');
        _toolsLoading = false;
      });
      return;
    }
    refresh(() {
      _toolsLoading = true;
      _toolsError = null;
    });
    try {
      final tools = await _toolsRepository.listTools(
        token,
        groupId: _activeGroupId,
        includeInactive: true,
      );
      if (!mounted) return;
      refresh(() {
        _tools = tools;
        _toolsLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      refresh(() {
        _toolsError = error.message;
        _toolsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _toolsError = _tx(
          'knowledge.load_error_tools',
          'No se pudieron cargar las herramientas',
        );
        _toolsLoading = false;
      });
    }
  }

  Future<void> _openCreateToolDialog() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ToolFormDialog(tx: _tx),
    );
    if (payload == null) return;
    await _saveTool(payload);
  }

  Future<void> _openEditToolDialog(ToolItem item) async {
    if (item.readOnly) {
      showMessage(
        _tx(
          'knowledge.readonly_tool',
          'Esta herramienta no es editable (del sistema o compartida)',
        ),
      );
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _toolsRepository.getTool(token, item.scope, item.id);
    } catch (_) {}

    if (!mounted) return;
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ToolFormDialog(tx: _tx, initial: initial),
    );
    if (payload == null) return;
    payload['id'] = item.id;
    await _saveTool(payload);
  }

  /// Guardado en dos pasos para `cpp`: primero `POST /api/tools/{scope}`
  /// (metadatos), y solo si el diálogo dejó un fichero pendiente,
  /// `uploadToolBinary(...)` después con el id ya asignado por el backend.
  Future<bool> _saveTool(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty) return false;
    final scope = (payload.remove('scope') as String?) ?? 'private';
    final pendingFileName = payload.remove('__binaryFileName') as String?;
    final pendingBytes = payload.remove('__binaryBytes') as List<int>?;
    try {
      final saved = await _toolsRepository.saveTool(token, scope, payload);
      if (pendingFileName != null && pendingBytes != null) {
        final savedId = (saved['id'] ?? payload['id'])?.toString() ?? '';
        final savedScope = (saved['scope'] as String?) ?? scope;
        if (savedId.isNotEmpty) {
          await _toolsRepository.uploadToolBinary(
            token,
            savedScope,
            savedId,
            fileName: pendingFileName,
            fileBytes: pendingBytes,
          );
        }
      }
      showMessage(_tx('knowledge.tool_saved', 'Herramienta guardada'));
      await _loadTools();
      return true;
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('knowledge.tool_save_error', 'No se pudo guardar la herramienta'),
        isError: true,
      );
    }
    return false;
  }

  Future<void> _toggleToolActive(ToolItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final activate = !item.isActive;
    try {
      await _toolsRepository.setToolActive(token, item.id, activate);
      showMessage(
        activate
            ? _tx('knowledge.tool_activated', 'Herramienta activada')
            : _tx('knowledge.tool_deactivated', 'Herramienta desactivada'),
      );
      await _loadTools();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx(
          'knowledge.tool_toggle_error',
          'No se pudo cambiar el estado de la herramienta',
        ),
        isError: true,
      );
    }
  }

  Future<void> _deleteTool(ToolItem item) async {
    if (item.readOnly) {
      showMessage(
        _tx(
          'knowledge.readonly_tool_delete',
          'Esta herramienta no se puede eliminar (del sistema o compartida)',
        ),
      );
      return;
    }
    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('knowledge.delete_tool_title', 'Eliminar herramienta'),
      message: _tx(
        'knowledge.delete_tool_confirm',
        '¿Seguro que quieres eliminar "{name}"?',
      ).replaceAll('{name}', item.name),
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      confirmLabel: _tx('common.delete', 'Eliminar'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _toolsRepository.deleteTool(token, item.scope, item.id);
      showMessage(_tx('knowledge.tool_deleted', 'Herramienta eliminada'));
      await _loadTools();
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx(
          'knowledge.tool_delete_error',
          'No se pudo eliminar la herramienta',
        ),
        isError: true,
      );
    }
  }

  Future<void> _shareTool(ToolItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'tool',
      resourceId: item.id,
      localeController: widget.localeController,
      onShared: _loadTools,
    );
  }

  Future<void> _showToolHistory(ToolItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showResourceHistoryDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'tool',
      resourceId: item.id,
      localeController: widget.localeController,
      onRestored: _loadTools,
    );
  }

  Future<void> _downloadToolBinary(ToolItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final result = await _toolsRepository.downloadToolBinary(
        token,
        item.scope,
        item.id,
      );
      await FilePicker.saveFile(
        dialogTitle: _tx('knowledge.download_binary', 'Descargar binario'),
        fileName: result.filename ?? item.binaryFilename ?? '${item.id}.bin',
        bytes: result.bytes,
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx(
          'knowledge.binary_download_error',
          'No se pudo descargar el binario',
        ),
        isError: true,
      );
    }
  }
}
