part of '../pages/agents_page.dart';

extension _AgentsPageImportActions on _AgentsPageState {
  Future<void> _pickAgentDirectory() async {
    final token = _token;
    if (token == null || token.isEmpty || _importingAgentFile) return;
    try {
      final selection = await pickKnowledgeDirectory(
        calculateChecksums: false,
        kind: DirectoryImportKind.agent,
      );
      if (!mounted || selection == null) return;
      try {
        if (selection.files.isEmpty) {
          showMessage(_tx('agents.directory_empty'), isError: true);
          return;
        }
        await _reviewAgentDirectoryFiles(selection.files);
      } finally {
        await selection.dispose();
      }
    } catch (_) {
      if (mounted) {
        showMessage(_tx('agents.directory_import_failed'), isError: true);
      }
    }
  }

  Future<void> _reviewAgentDirectoryFiles(List<LocalKnowledgeFile> files) async {
    final token = _token;
    if (token == null || token.isEmpty || _importingAgentFile) return;
    refresh(() => _importingAgentFile = true);
    try {
      final plan = await _agentImportRepository.previewDirectory(token, files: files);
      if (!mounted) return;
      if (!plan.components.any((item) => item.isAgent)) {
        showMessage(_tx('agents.directory_no_agents'), isError: true);
        return;
      }
      final options = await showAgentDirectoryImportDialog(
        context: context,
        plan: plan,
        resourceOptions: _agentImportResourceOptions(),
        tx: _tx,
        pageLoader: _loadAgentResourcePage,
      );
      if (!mounted || options == null) return;
      final result = await _agentImportRepository.applyDirectory(
        token,
        files: files,
        sessionId: plan.sessionId,
        options: options,
      );
      if (!mounted) return;
      showMessage(_tx('agents.directory_imported_count').replaceAll('{{count}}', '${result.agentCount}'));
      await _reloadAfterDirectoryImport();
    } on ApiError catch (error) {
      if (mounted) showMessage(error.message, isError: true);
    } catch (_) {
      if (mounted) {
        showMessage(_tx('agents.directory_import_failed'), isError: true);
      }
    } finally {
      if (mounted) refresh(() => _importingAgentFile = false);
    }
  }

  bool _isSupportedAgentFile(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.md') || lower.endsWith('.json');
  }

  Future<void> _pickAgentFile() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['md', 'json'],
        allowMultiple: false,
        withData: true,
      );
    } catch (_) {
      showMessage(_tx('agents.import_pick_failed'), isError: true);
      return;
    }
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showMessage(_tx('agents.import_unreadable'), isError: true);
      return;
    }
    await _previewAgentFile(file.name, bytes);
  }

  Future<void> _handleAgentDrop(DropDoneDetails details) async {
    if (mounted) refresh(() => _draggingAgentFile = false);
    if (details.files case [final DropItemDirectory directory]) {
      try {
        final selection = await collectDroppedDirectory(
          directory.children,
          kind: DirectoryImportKind.agent,
          calculateChecksums: false,
        );
        if (!mounted) return;
        if (selection.files.isEmpty) {
          showMessage(_tx('agents.directory_empty'), isError: true);
          return;
        }
        await _reviewAgentDirectoryFiles(selection.files);
      } catch (_) {
        if (mounted) {
          showMessage(_tx('agents.directory_import_failed'), isError: true);
        }
      }
      return;
    }
    if (details.files.length != 1) {
      showMessage(_tx('agents.import_one_file_only'), isError: true);
      return;
    }
    final file = details.files.single;
    if (!_isSupportedAgentFile(file.name)) {
      showMessage(_tx('agents.import_unsupported'), isError: true);
      return;
    }
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.isEmpty) {
        showMessage(_tx('agents.import_unreadable'), isError: true);
        return;
      }
      await _previewAgentFile(file.name, bytes);
    } catch (_) {
      if (mounted) {
        showMessage(_tx('agents.import_unreadable'), isError: true);
      }
    }
  }

  Future<void> _previewAgentFile(String fileName, Uint8List bytes) async {
    if (!_isSupportedAgentFile(fileName)) {
      showMessage(_tx('agents.import_unsupported'), isError: true);
      return;
    }
    if (UploadLimits.exceeds(bytes.length)) {
      showMessage(
        _tx('agents.import_too_large')
            .replaceAll('{limit}', UploadLimits.formatted),
        isError: true,
      );
      return;
    }
    final token = _token;
    if (token == null || token.isEmpty || _importingAgentFile) return;
    refresh(() => _importingAgentFile = true);

    AgentImportPreview preview;
    try {
      preview = await _agentImportRepository.previewFile(
        token,
        fileName: fileName,
        bytes: bytes,
      );
    } on ApiError catch (error) {
      final reason = error.extra['reason']?.toString();
      final serverLimit = error.extra['limit_bytes'];
      final message = switch ((error.code, reason)) {
        ('payload_too_large', _) => _tx('agents.import_too_large').replaceAll(
          '{limit}',
          serverLimit is num
              ? UploadLimits.formatBytes(serverLimit.toInt())
              : UploadLimits.formatted,
        ),
        (_, 'invalid_encoding') => _tx('agents.import_invalid_encoding'),
        (_, 'binary_content') => _tx('agents.import_invalid_encoding'),
        (_, 'invalid_json') => _tx('agents.import_invalid_json'),
        (_, 'invalid_json_shape') => _tx('agents.import_invalid_json'),
        (_, 'invalid_frontmatter') => _tx('agents.import_invalid_frontmatter'),
        (_, 'invalid_frontmatter_shape') => _tx(
          'agents.import_invalid_frontmatter',
        ),
        (_, 'unsupported_extension') => _tx('agents.import_unsupported'),
        (_, 'empty') => _tx('agents.import_unreadable'),
        _ => error.message,
      };
      showMessage(message, isError: true);
      return;
    } catch (_) {
      showMessage(_tx('agents.import_preview_failed'), isError: true);
      return;
    } finally {
      if (mounted) refresh(() => _importingAgentFile = false);
    }
    if (!mounted) return;

    final linkedResources = await showAgentImportPreviewDialog(
      context: context,
      preview: preview,
      tx: _tx,
      resourceOptions: _agentImportResourceOptions(),
      pageLoader: _loadAgentResourcePage,
    );
    if (linkedResources == null || !mounted) return;

    final currentToken = _token;
    if (currentToken == null || currentToken.isEmpty) return;
    final payload = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => AgentFormPage(
          apiClient: _services.apiClient,
          token: currentToken,
          initial: preview.draft.toFormInitial(
            linkedResources: linkedResources.toAgentFields(),
          ),
          tx: _tx,
          resourceCatalog: _agentResourceCatalog,
          resourcePageLoader: _loadAgentResourcePage,
        ),
      ),
    );
    if (payload == null) return;
    await _saveAgent(payload);
  }

  Future<AgentResourceOptionPage> _loadAgentResourcePage(
    AgentResourceType type,
    String query,
    int offset,
  ) {
    final token = _token;
    if (token == null || token.isEmpty) {
      return Future.value(
        const AgentResourceOptionPage(items: [], hasMore: false),
      );
    }
    return _agentImportRepository.searchCatalog(
      token,
      type,
      query: query,
      offset: offset,
    );
  }

  List<AgentResourceOption> _agentImportResourceOptions() => [
    for (final entry in _skillNames.entries)
      AgentResourceOption(
        id: entry.key,
        type: AgentResourceType.skill,
        title: entry.value,
      ),
    for (final entry in _knowledgeNames.entries)
      AgentResourceOption(
        id: entry.key,
        type: AgentResourceType.knowledge,
        title: entry.value,
      ),
    for (final entry in _knowledgePackNames.entries)
      AgentResourceOption(
        id: entry.key,
        type: AgentResourceType.knowledgePack,
        title: entry.value,
      ),
    for (final entry in _promptNames.entries)
      AgentResourceOption(
        id: entry.key,
        type: AgentResourceType.prompt,
        title: entry.value,
      ),
    for (final entry in _toolNames.entries)
      AgentResourceOption(
        id: entry.key,
        type: AgentResourceType.tool,
        title: entry.value,
      ),
  ];
}
