part of '../pages/knowledge_page.dart';

extension _KnowledgeActions on _KnowledgePageState {
  String? get _token => widget.sessionController.gaToken;

  Future<void> _loadSkills() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _refresh(() {
        _skillsError = 'No hay sesión activa';
        _skillsLoading = false;
      });
      return;
    }
    _refresh(() {
      _skillsLoading = true;
      _skillsError = null;
    });
    try {
      final skills = await _skillsRepository.listSkills(
        token,
        groupId: _activeGroupId,
        includeInactive: true,
      );
      if (!mounted) return;
      _refresh(() {
        _skills = skills;
        _skillsLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      _refresh(() {
        _skillsError = error.message;
        _skillsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _refresh(() {
        _skillsError = 'No se pudieron cargar las skills';
        _skillsLoading = false;
      });
    }
  }

  Future<void> _openCreateSkillDialog() async {
    final allowPublic = widget.sessionController.user?.role != 'guest';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SkillFormDialog(allowPublic: allowPublic),
    );
    if (payload == null) return;
    await _saveSkill(payload);
  }

  Future<void> _openCreateSkillChoiceDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          _tx(
            'skill_builder.create_choice_title',
            '¿Cómo quieres crear la skill?',
          ),
        ),
        children: [
          _skillCreateChoiceOption(
            context,
            icon: Icons.edit_note_outlined,
            title: _tx('skill_builder.create_choice_scratch', 'Desde cero'),
            subtitle: _tx(
              'skill_builder.create_choice_scratch_desc',
              'Un formulario en blanco para definir cada campo.',
            ),
            value: 'scratch',
          ),
          _skillCreateChoiceOption(
            context,
            icon: Icons.auto_awesome_outlined,
            title: _tx('skill_builder.create_choice_ai', 'Con ayuda de IA'),
            subtitle: _tx(
              'skill_builder.create_choice_ai_desc',
              'Descríbela en una conversación y revisa el borrador.',
            ),
            value: 'ai',
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == 'scratch') {
      await _openCreateSkillDialog();
    } else if (choice == 'ai') {
      await _openSkillBuilder();
    }
  }

  Widget _skillCreateChoiceOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    return SimpleDialogOption(
      onPressed: () => Navigator.of(context).pop(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSkillBuilder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SkillBuilderPage(
          apiClient: widget.apiClient,
          sessionController: widget.sessionController,
          localeController: widget.localeController,
          onReviewDraft: _reviewAndSaveSkillDraft,
        ),
      ),
    );
    if (created == true) await _loadSkills();
  }

  Future<bool> _reviewAndSaveSkillDraft(Map<String, dynamic> draft) async {
    if (!mounted) return false;
    final allowPublic = widget.sessionController.user?.role != 'guest';
    final initial = <String, dynamic>{...draft, 'scope': 'private'};
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SkillFormDialog(
        initial: initial,
        allowPublic: allowPublic,
        requireQualityContent: true,
      ),
    );
    if (payload == null) return false;
    return _saveSkill(payload);
  }

  Future<void> _openEditSkillDialog(SkillItem item) async {
    if (item.readOnly) {
      _showMessage('Esta skill no es editable (del sistema o compartida)');
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _skillsRepository.getSkill(token, item.scope, item.id);
    } catch (_) {}

    if (!mounted) return;
    final allowPublic = widget.sessionController.user?.role != 'guest';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _SkillFormDialog(initial: initial, allowPublic: allowPublic),
    );
    if (payload == null) return;
    payload['id'] = item.id;
    await _saveSkill(payload);
  }

  Future<bool> _saveSkill(Map<String, dynamic> payload) async {
    final token = _token;
    if (token == null || token.isEmpty) return false;
    final scope = (payload.remove('scope') as String?) ?? 'private';
    try {
      await _skillsRepository.saveSkill(token, scope, payload);
      _showMessage('Skill guardada');
      await _loadSkills();
      return true;
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo guardar la skill', isError: true);
    }
    return false;
  }

  Future<void> _toggleSkillActive(SkillItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final activate = !item.isActive;
    try {
      await _skillsRepository.setSkillActive(token, item.id, activate);
      _showMessage(activate ? 'Skill activada' : 'Skill desactivada');
      await _loadSkills();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo cambiar el estado de la skill', isError: true);
    }
  }

  Future<void> _deleteSkill(SkillItem item) async {
    if (item.readOnly) {
      _showMessage(
        'Esta skill no se puede eliminar (del sistema o compartida)',
      );
      return;
    }
    final confirm = await showConfirmActionDialog(
      context,
      title: 'Eliminar skill',
      message: '¿Seguro que quieres eliminar "${item.name}"?',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Eliminar',
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _skillsRepository.deleteSkill(token, item.scope, item.id);
      _showMessage('Skill eliminada');
      await _loadSkills();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar la skill', isError: true);
    }
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      _refresh(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }

    _refresh(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await _repository.listItems(
        token,
        groupId: _activeGroupId,
        includeInactive: true,
      );
      if (!mounted) return;
      _refresh(() {
        _items = items;
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      _refresh(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      _refresh(() {
        _error = 'No se pudo cargar Knowledge';
        _loading = false;
      });
    }
  }

  Future<void> _openAddTextDialog() async {
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddTextDialog(),
    );
    if (payload == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.addText(
        token,
        title: payload['title'] ?? '',
        source: payload['source'],
        content: payload['content'] ?? '',
      );
      _showMessage('Texto añadido a Knowledge');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo guardar el texto', isError: true);
    }
  }

  Future<void> _openAddUrlDialog() async {
    final payload = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const _AddUrlDialog(),
    );
    if (payload == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.addUrl(
        token,
        url: payload['url'] ?? '',
        title: payload['title'],
      );
      _showMessage('URL importada a Knowledge');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo importar la URL', isError: true);
    }
  }

  Future<void> _uploadDocument() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['txt', 'md', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _showMessage('No se pudieron leer los bytes del fichero', isError: true);
      return;
    }

    _refresh(() => _uploading = true);
    try {
      await _repository.uploadDocument(
        token,
        fileName: file.name,
        fileBytes: bytes,
      );
      _showMessage('Documento subido: ${file.name}');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo subir el documento', isError: true);
    } finally {
      if (mounted) _refresh(() => _uploading = false);
    }
  }

  Future<void> _toggleItemActive(KnowledgeItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    final activate = !item.isActive;
    try {
      await _repository.setItemActive(token, item.id, activate);
      _showMessage(
        activate ? 'Conocimiento activado' : 'Conocimiento desactivado',
      );
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo cambiar el estado del item', isError: true);
    }
  }

  Future<void> _deleteItem(KnowledgeItem item) async {
    final confirm = await showConfirmActionDialog(
      context,
      title: 'Eliminar item',
      message: '¿Seguro que quieres eliminar "${item.title}"?',
      cancelLabel: 'Cancelar',
      confirmLabel: 'Eliminar',
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteItem(token, item.id);
      _showMessage('Item eliminado');
      await _load();
    } on ApiError catch (error) {
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage('No se pudo eliminar el item', isError: true);
    }
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? FncColors.materialRed.shade700 : null,
      ),
    );
  }

  void _onGroupSelect(String? groupId) {
    _refresh(() => _activeGroupId = groupId);
    _load();
    _loadSkills();
    _loadPrompts();
  }

  Future<void> _shareItem(KnowledgeItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'knowledge',
      resourceId: item.id,
      localeController: widget.localeController,
      onShared: _load,
    );
  }

  Future<void> _shareSkill(SkillItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'skill',
      resourceId: item.id,
      localeController: widget.localeController,
      onShared: _loadSkills,
    );
  }

  Future<void> _showSkillHistory(SkillItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showResourceHistoryDialog(
      context: context,
      apiClient: widget.apiClient,
      token: token,
      resourceType: 'skill',
      resourceId: item.id,
      localeController: widget.localeController,
      onRestored: _loadSkills,
    );
  }
}
