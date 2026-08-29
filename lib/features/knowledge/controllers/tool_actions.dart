part of '../pages/knowledge_page.dart';

/// Acciones CRUD de Tools: calco de `_KnowledgeActions` para skills,
/// separado en su propio fichero para no hacer crecer sin límite
/// `knowledge_actions.dart` (ver `feature_architecture_test.dart`).
extension _ToolActions on _KnowledgePageState {
  Future<void> _loadTools() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      refresh(() {
        _toolsError = _tx('common.no_session');
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
        _toolsError = _tx('knowledge.load_error_tools');
        _toolsLoading = false;
      });
    }
  }

  Future<void> _openCreateToolDialog() async {
    final result = await showAppDialog<ToolFormResult>(
      context: context,
      builder: (context) => _ToolFormDialog(tx: _tx),
    );
    if (result == null) return;
    await _saveTool(result);
  }

  Future<void> _openEditToolDialog(ToolItem item) async {
    if (item.readOnly) {
      showMessage(_tx('knowledge.readonly_tool'));
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _toolsRepository.getTool(token, item.scope, item.id);
    } catch (_) {}

    if (!mounted) return;
    final result = await showAppDialog<ToolFormResult>(
      context: context,
      builder: (context) => _ToolFormDialog(tx: _tx, initial: initial),
    );
    if (result == null) return;
    result.payload['id'] = item.id;
    await _saveTool(result);
  }

  /// Guardado en dos pasos para `cpp`: primero `POST /api/tools/{scope}`
  /// (metadatos), y solo si el diálogo dejó un fichero pendiente,
  /// transmite el binario después con el id ya asignado por el backend.
  Future<bool> _saveTool(ToolFormResult result) async {
    final token = _token;
    if (token == null || token.isEmpty) return false;
    final payload = result.payload;
    final scope = (payload.remove('scope') as String?) ?? 'private';
    final artifact = result.artifact;
    try {
      final saved = await _toolsRepository.saveTool(token, scope, payload);
      if (artifact != null) {
        final savedId = (saved['id'] ?? payload['id'])?.toString() ?? '';
        final savedScope = (saved['scope'] as String?) ?? scope;
        if (savedId.isNotEmpty) {
          await _toolsRepository.uploadToolBinaryStream(
            token,
            savedScope,
            savedId,
            fileName: artifact.fileName,
            // La función, no su resultado: el reintento tras renovar la
            // sesión necesita un stream nuevo.
            fileStream: artifact.openRead,
            fileLength: artifact.size,
          );
        }
      }
      showMessage(_tx('knowledge.tool_saved'));
      return true;
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.tool_save_error'), isError: true);
    }
    return false;
  }

  Future<void> _deleteTool(ToolItem item) async {
    if (item.readOnly) {
      showMessage(_tx('knowledge.readonly_tool_delete'));
      return;
    }
    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('knowledge.delete_tool_title'),
      message: _tx('knowledge.delete_tool_confirm')
          .replaceAll('{name}', item.name),
      cancelLabel: _tx('common.cancel'),
      confirmLabel: _tx('common.delete'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _toolsRepository.deleteTool(token, item.scope, item.id);
      showMessage(_tx('knowledge.tool_deleted'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.tool_delete_error'), isError: true);
    }
  }

  Future<void> _toggleToolActive(ToolItem item) async {
    final token = _token;
    if (token == null || token.isEmpty || item.readOnly) return;
    final active = !item.isActive;
    try {
      await _toolsRepository.setToolActive(token, item.scope, item.id, active);
      showMessage(
        _tx(
          active
              ? 'knowledge.content_activated'
              : 'knowledge.content_deactivated',
        ),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.msg_item_toggle_failed'), isError: true);
    }
  }

  Future<void> _shareTool(ToolItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'tool',
      resourceId: item.id,
      localeController: _services.localeController,
      onShared: _loadTools,
    );
  }

  Future<void> _showToolHistory(ToolItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showResourceHistoryDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'tool',
      resourceId: item.id,
      localeController: _services.localeController,
      onRestored: _loadTools,
    );
  }

  Future<void> _downloadToolBinary(ToolItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      final download = await _toolsRepository.downloadToolBinaryStream(
        token,
        item.scope,
        item.id,
      );
      final result = await saveStreamedFile(
        stream: download.stream,
        dialogTitle: _tx('knowledge.download_binary'),
        fileName: download.filename ?? item.binaryFilename ?? '${item.id}.bin',
        expectedSha256: download.sha256 ?? item.binarySha256,
      );
      if (result == StreamedFileSaveResult.checksumMismatch) {
        showMessage(_tx('knowledge.binary_checksum_mismatch'), isError: true);
      }
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.binary_download_error'), isError: true);
    }
  }
}
