part of '../pages/knowledge_page.dart';

/// Acciones CRUD de Prompts: calco de `_KnowledgeActions` para skills,
/// separado en su propio fichero para no hacer crecer sin límite
/// `knowledge_actions.dart` (ver `feature_architecture_test.dart`).
extension _PromptActions on _KnowledgePageState {
  Future<void> _loadPrompts() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _refresh(() {
        _promptsError = _tx('common.no_session', 'No hay sesión activa');
        _promptsLoading = false;
      });
      return;
    }
    _refresh(() {
      _promptsLoading = true;
      _promptsError = null;
    });
    try {
      final prompts = await _promptsRepository.listPrompts(
        token,
        groupId: _activeGroupId,
        includeInactive: true,
      );
      if (!mounted) return;
      _refresh(() {
        _prompts = prompts;
        _promptsLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      _refresh(() {
        _promptsError = error.message;
        _promptsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _refresh(() {
        _promptsError = _tx(
          'knowledge.load_error_prompts',
          'No se pudieron cargar los prompts',
        );
        _promptsLoading = false;
      });
    }
  }

  Future<void> _openCreatePromptDialog() async {
    final allowPublic = widget.sessionController.user?.role != 'guest';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _PromptFormDialog(tx: _tx, allowPublic: allowPublic),
    );
    if (payload == null) return;
    await _savePrompt(payload);
  }

  Future<void> _openEditPromptDialog(PromptItem item) async {
    if (item.readOnly) {
      _showMessage(
        _tx(
          'knowledge.readonly_prompt',
          'Este prompt no es editable (del sistema o compartido)',
        ),
      );
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _promptsRepository.getPrompt(token, item.scope, item.id);
    } catch (_) {}

    if (!mounted) return;
    final allowPublic = widget.sessionController.user?.role != 'guest';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PromptFormDialog(
        tx: _tx,
        initial: initial,
        allowPublic: allowPublic,
      ),
    );
    if (payload == null) return;
    payload['id'] = item.id;
    await _savePrompt(payload);
  }

  Future<bool> _savePrompt(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty) return false;
    final scope = (payload.remove('scope') as String?) ?? 'private';
    try {
      await _promptsRepository.savePrompt(token, scope, payload);
      _showMessage(_tx('knowledge.prompt_saved', 'Prompt guardado'));
      await _loadPrompts();
      return true;
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('knowledge.prompt_save_error', 'No se pudo guardar el prompt'),
        isError: true,
      );
    }
    return false;
  }

  Future<void> _togglePromptActive(PromptItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final activate = !item.isActive;
    try {
      await _promptsRepository.setPromptActive(token, item.id, activate);
      _showMessage(
        activate
            ? _tx('knowledge.prompt_activated', 'Prompt activado')
            : _tx('knowledge.prompt_deactivated', 'Prompt desactivado'),
      );
      await _loadPrompts();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx(
          'knowledge.prompt_toggle_error',
          'No se pudo cambiar el estado del prompt',
        ),
        isError: true,
      );
    }
  }

  Future<void> _deletePrompt(PromptItem item) async {
    if (item.readOnly) {
      _showMessage(
        _tx(
          'knowledge.readonly_prompt_delete',
          'Este prompt no se puede eliminar (del sistema o compartido)',
        ),
      );
      return;
    }
    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('knowledge.delete_prompt_title', 'Eliminar prompt'),
      message: _tx(
        'knowledge.delete_prompt_confirm',
        '¿Seguro que quieres eliminar "{name}"?',
      ).replaceAll('{name}', item.name),
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      confirmLabel: _tx('common.delete', 'Eliminar'),
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _promptsRepository.deletePrompt(token, item.scope, item.id);
      _showMessage(_tx('knowledge.prompt_deleted', 'Prompt eliminado'));
      await _loadPrompts();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(
        _tx('knowledge.prompt_delete_error', 'No se pudo eliminar el prompt'),
        isError: true,
      );
    }
  }

  Future<void> _sharePrompt(PromptItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'prompt',
      resourceId: item.id,
      localeController: widget.localeController,
      onShared: _loadPrompts,
    );
  }

  Future<void> _showPromptHistory(PromptItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showResourceHistoryDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'prompt',
      resourceId: item.id,
      localeController: widget.localeController,
      onRestored: _loadPrompts,
    );
  }
}
