part of '../pages/knowledge_page.dart';

extension _KnowledgeActions on _KnowledgePageState {
  String? get _token => _services.sessionController.gaToken;

  Future<void> _loadSkills() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      refresh(() {
        _skillsError = tr('common.no_session');
        _skillsLoading = false;
      });
      return;
    }
    refresh(() {
      _skillsLoading = true;
      _skillsError = null;
    });
    try {
      final skills = await _skillsRepository.listSkills(
        token,
        groupId: _activeGroupId,
      );
      if (!mounted) return;
      refresh(() {
        _skills = skills;
        _skillsLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      refresh(() {
        _skillsError = error.message;
        _skillsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _skillsError = tr('knowledge.skills_load_error');
        _skillsLoading = false;
      });
    }
  }

  Future<void> _openCreateSkillDialog() async {
    final allowPublic = _services.sessionController.user?.role != 'guest';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SkillFormDialog(tx: _tx, allowPublic: allowPublic),
    );
    if (payload == null) return;
    await _saveSkill(payload);
  }

  Future<void> _openCreateSkillChoiceDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(_tx('skill_builder.create_choice_title')),
        children: [
          _skillCreateChoiceOption(
            context,
            icon: Icons.edit_note_outlined,
            title: _tx('skill_builder.create_choice_scratch'),
            subtitle: _tx('skill_builder.create_choice_scratch_desc'),
            value: 'scratch',
          ),
          _skillCreateChoiceOption(
            context,
            icon: Icons.auto_awesome_outlined,
            title: _tx('skill_builder.create_choice_ai'),
            subtitle: _tx('skill_builder.create_choice_ai_desc'),
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
    // La lista se refresca sola: crear la skill pasa por la API y eso avisa
    // a las vistas que miran «skills».
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => SkillBuilderPage(
          apiClient: _services.apiClient,
          sessionController: _services.sessionController,
          localeController: _services.localeController,
          onReviewDraft: _reviewAndSaveSkillDraft,
        ),
      ),
    );
  }

  Future<bool> _reviewAndSaveSkillDraft(Map<String, dynamic> draft) async {
    if (!mounted) return false;
    final allowPublic = _services.sessionController.user?.role != 'guest';
    final initial = <String, dynamic>{...draft, 'scope': 'private'};
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _SkillFormDialog(
        tx: _tx,
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
      showMessage(_tx('knowledge.msg_skill_not_editable'));
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty) return;

    Map<String, dynamic> initial = item.raw;
    try {
      initial = await _skillsRepository.getSkill(token, item.scope, item.id);
    } catch (_) {}

    if (!mounted) return;
    final allowPublic = _services.sessionController.user?.role != 'guest';
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _SkillFormDialog(tx: _tx, initial: initial, allowPublic: allowPublic),
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
      showMessage(_tx('knowledge.msg_skill_saved'));
      return true;
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.msg_skill_save_failed'), isError: true);
    }
    return false;
  }

  Future<void> _deleteSkill(SkillItem item) async {
    if (item.readOnly) {
      showMessage(_tx('knowledge.msg_skill_not_deletable'));
      return;
    }
    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('knowledge.delete_skill_dialog_title'),
      message: _tx(
        'common.delete_confirm_body',
      ).replaceAll('{{nombre}}', item.name),
      cancelLabel: 'Cancelar',
      confirmLabel: _tx('common.delete'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _skillsRepository.deleteSkill(token, item.scope, item.id);
      showMessage(_tx('knowledge.msg_skill_deleted'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.msg_skill_delete_failed'), isError: true);
    }
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      refresh(() {
        _error = tr('common.no_session');
        _loading = false;
      });
      return;
    }

    refresh(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _repository.listItemPage(token, groupId: _activeGroupId),
        _repository.listPacks(token, groupId: _activeGroupId),
      ]);
      if (!mounted) return;
      refresh(() {
        final page = results[0] as PageResult<KnowledgeItem>;
        _items = page.items;
        _hasMoreKnowledge = page.hasMore;
        _loadingMoreKnowledge = false;
        _packs = results[1] as List<KnowledgePack>;
        _loading = false;
      });
      await _ensureKnowledgeCollectionFilled();
    } on ApiError catch (error) {
      if (!mounted) return;
      refresh(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _error = 'No se pudo cargar Knowledge';
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreKnowledge() async {
    final token = _token;
    if (token == null ||
        !_hasMoreKnowledge ||
        _loadingMoreKnowledge ||
        _loading) {
      return;
    }
    refresh(() => _loadingMoreKnowledge = true);
    try {
      final page = await _repository.listItemPage(
        token,
        groupId: _activeGroupId,
        offset: _items.length,
      );
      if (!mounted) return;
      final known = _items.map((item) => item.id).toSet();
      refresh(() {
        _items = [..._items, ...page.items.where((item) => known.add(item.id))];
        _hasMoreKnowledge = page.hasMore;
        _loadingMoreKnowledge = false;
      });
    } catch (_) {
      if (mounted) refresh(() => _loadingMoreKnowledge = false);
    }
  }

  /// Sigue pidiendo páginas mientras la vista se quede corta.
  ///
  /// El origen y el modo packs se filtran en cliente sobre una lista paginada,
  /// así que una página entera puede no dejar ni un elemento visible. Y sin
  /// elementos no hay scroll, sin scroll no hay `ScrollNotification` y sin ella
  /// nadie pide la página siguiente: el usuario veía «no hay documentos» con
  /// sus documentos esperando en la página dos.
  Future<void> _ensureKnowledgeCollectionFilled() async {
    // Cota dura: si el servidor devolviese siempre páginas sin nada visible,
    // esto no puede convertirse en un bucle que se coma la sesión.
    for (var intento = 0; intento < 20; intento++) {
      if (!mounted || !_hasMoreKnowledge) return;
      if (_knowledgeCollection.length >= _minVisibleKnowledgeItems) return;
      final antes = _items.length;
      await _loadMoreKnowledge();
      if (!mounted || _items.length == antes) return;
    }
  }

  Future<void> _openAddTextDialog() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddTextDialog(tx: _tx),
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
        labels:
            (payload['labels'] as List?)
                ?.map((value) => value.toString())
                .toList() ??
            const ['private'],
      );
      showMessage(_tx('knowledge.msg_text_added'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.msg_text_failed'), isError: true);
    }
  }

  Future<void> _openAddUrlDialog() async {
    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddUrlDialog(tx: _tx),
    );
    if (payload == null) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.addUrl(
        token,
        url: payload['url'] ?? '',
        title: payload['title'],
        labels:
            (payload['labels'] as List?)
                ?.map((value) => value.toString())
                .toList() ??
            const ['private'],
      );
      showMessage(_tx('knowledge.msg_url_imported'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.msg_url_failed'), isError: true);
    }
  }

  Future<void> _deleteItem(KnowledgeItem item) async {
    final confirm = await showConfirmActionDialog(
      context,
      title: _tx('knowledge.delete_item_dialog_title'),
      message: _tx(
        'common.delete_confirm_body',
      ).replaceAll('{{nombre}}', item.title),
      cancelLabel: 'Cancelar',
      confirmLabel: _tx('common.delete'),
      destructive: true,
    );
    if (!confirm) return;

    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await _repository.deleteItem(token, item.id);
      showMessage(_tx('knowledge.msg_item_deleted'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.msg_item_delete_failed'), isError: true);
    }
  }

  Future<void> _editItem(KnowledgeItem item) async {
    final result = await _showKnowledgeEditDialog(
      context,
      initialName: item.title,
      initialLabels: item.labels.toSet(),
      isPack: false,
      tx: _tx,
    );
    if (result == null || !mounted) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.updateItem(
        token,
        item.id,
        name: result.name,
        labels: result.labels.toList(),
      );
      showMessage(_tx('knowledge.edit_saved'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.edit_failed'), isError: true);
    }
  }

  void _onGroupSelect(String? groupId) {
    refresh(() => _activeGroupId = groupId);
    _invalidateGraphRelations();
    _load();
    _loadSkills();
    _loadPrompts();
    _loadTools();
  }

  Future<void> _shareItem(KnowledgeItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'knowledge',
      resourceId: item.id,
      localeController: _services.localeController,
      onShared: _load,
    );
  }

  Future<void> _shareSkill(SkillItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'skill',
      resourceId: item.id,
      localeController: _services.localeController,
      onShared: _loadSkills,
    );
  }

  Future<void> _showSkillHistory(SkillItem item) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showResourceHistoryDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'skill',
      resourceId: item.id,
      localeController: _services.localeController,
      onRestored: _loadSkills,
    );
  }
}
