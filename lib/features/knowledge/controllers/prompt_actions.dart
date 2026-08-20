part of '../pages/knowledge_page.dart';

/// Acciones CRUD de Prompts: calco de `_KnowledgeActions` para skills,
/// separado en su propio fichero para no hacer crecer sin límite
/// `knowledge_actions.dart` (ver `feature_architecture_test.dart`).
extension _PromptActions on _KnowledgePageState {
  Future<void> _loadPrompts() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      refresh(() {
        _promptsError = _tx('common.no_session');
        _promptsLoading = false;
      });
      return;
    }
    refresh(() {
      _promptsLoading = true;
      _promptsError = null;
    });
    try {
      final prompts = await _promptsRepository.listPrompts(
        token,
        groupId: _activeGroupId,
      );
      if (!mounted) return;
      refresh(() {
        _prompts = prompts;
        _promptsLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      refresh(() {
        _promptsError = error.message;
        _promptsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _promptsError = _tx('knowledge.load_error_prompts');
        _promptsLoading = false;
      });
    }
  }

  Future<void> _openCreatePromptDialog() async {
    final allowPublic = _services.sessionController.user?.role != 'guest';
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
      showMessage(_tx('knowledge.readonly_prompt'));
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _promptsRepository.getPrompt(token, item.scope, item.id);
    } catch (_) {}

    if (!mounted) return;
    final allowPublic = _services.sessionController.user?.role != 'guest';
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
      showMessage(_tx('knowledge.prompt_saved'));
      return true;
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.prompt_save_error'), isError: true);
    }
    return false;
  }

  Future<void> _deletePrompt(PromptItem item) async {
    if (item.readOnly) {
      showMessage(_tx('knowledge.readonly_prompt_delete'));
      return;
    }
    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('knowledge.delete_prompt_title'),
      message: _tx(
        'knowledge.delete_prompt_confirm',
      ).replaceAll('{name}', item.name),
      cancelLabel: _tx('common.cancel'),
      confirmLabel: _tx('common.delete'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _promptsRepository.deletePrompt(token, item.scope, item.id);
      showMessage(_tx('knowledge.prompt_deleted'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.prompt_delete_error'), isError: true);
    }
  }

  Future<void> _sharePrompt(PromptItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'prompt',
      resourceId: item.id,
      localeController: _services.localeController,
      onShared: _loadPrompts,
    );
  }

  Future<void> _showPromptHistory(PromptItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showResourceHistoryDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'prompt',
      resourceId: item.id,
      localeController: _services.localeController,
      onRestored: _loadPrompts,
    );
  }
}
