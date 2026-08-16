part of '../pages/knowledge_page.dart';

extension _KnowledgePackActions on _KnowledgePageState {
  Future<void> _pickKnowledgeDirectory() async {
    refresh(() {
      _uploading = true;
      _packOperationMessage = _tx(
        'knowledge.pack_selecting_directory',
        'Selecciona el directorio de conocimiento',
      );
    });
    KnowledgeDirectorySelection? selection;
    try {
      selection = await pickKnowledgeDirectory(onProgress: _showPackProgress);
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _uploading = false;
        _packOperationMessage = null;
      });
      showMessage(
        _tx(
          'knowledge.pack_read_failed',
          'No se pudo leer el directorio seleccionado',
        ),
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    refresh(() {
      _uploading = false;
      _packOperationMessage = null;
    });
    if (selection == null) return;
    if (selection.files.isEmpty) {
      showMessage(
        _tx(
          'knowledge.pack_no_compatible_files',
          'El directorio no contiene archivos de conocimiento compatibles. Las imágenes no se indexan todavía.',
        ),
        isError: true,
      );
      return;
    }
    await _reviewAndUploadPack(selection);
  }

  void _showPackProgress(KnowledgeDirectoryProgress progress) {
    if (!mounted) return;
    refresh(() {
      _packOperationMessage =
          _tx(
                'knowledge.pack_scanning_progress',
                'Organizando: {{compatible}} compatibles · {{ignored}} omitidos',
              )
              .replaceAll('{{compatible}}', '${progress.compatible}')
              .replaceAll('{{ignored}}', '${progress.ignored}');
    });
  }

  Future<void> _handleDirectoryDrop(DropDoneDetails details) async {
    refresh(() => _draggingDirectory = false);
    final directories = details.files.whereType<DropItemDirectory>().toList();
    if (directories.length != 1 || details.files.length != 1) {
      showMessage(
        _tx(
          'knowledge.pack_drop_one_directory',
          'Arrastra un único directorio para crear un pack',
        ),
        isError: true,
      );
      return;
    }
    final files = <LocalKnowledgeFile>[];
    final counters = [0, 0, 0];
    refresh(() {
      _uploading = true;
      _packOperationMessage = _tx(
        'knowledge.pack_scanning',
        'Analizando y organizando el directorio…',
      );
    });
    try {
      await _collectDroppedFiles(
        directories.single.children,
        '',
        files,
        counters,
      );
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _uploading = false;
        _packOperationMessage = null;
      });
      showMessage(
        _tx(
          'knowledge.pack_read_failed',
          'No se pudo leer el directorio seleccionado',
        ),
        isError: true,
      );
      return;
    }
    if (!mounted) return;
    refresh(() {
      _uploading = false;
      _packOperationMessage = null;
    });
    if (files.isEmpty) {
      showMessage(
        _tx(
          'knowledge.pack_no_compatible_files',
          'El directorio no contiene archivos de conocimiento compatibles. Las imágenes no se indexan todavía.',
        ),
        isError: true,
      );
      return;
    }
    await _reviewAndUploadPack(
      KnowledgeDirectorySelection(files: files, ignoredCount: counters[1]),
    );
  }

  Future<void> _collectDroppedFiles(
    List<DropItem> entries,
    String prefix,
    List<LocalKnowledgeFile> output,
    List<int> counters,
  ) async {
    for (final entry in entries) {
      final relative = prefix.isEmpty ? entry.name : '$prefix/${entry.name}';
      if (entry is DropItemDirectory) {
        if (!knowledgePackIgnoredDirectoryNames.contains(
          entry.name.toLowerCase(),
        )) {
          await _collectDroppedFiles(
            entry.children,
            relative,
            output,
            counters,
          );
        }
      } else {
        counters[0]++;
        if (!isSupportedKnowledgePackPath(relative)) {
          counters[1]++;
        } else {
          final bytes = await entry.readAsBytes();
          if (bytes.length > knowledgePackMaxFileBytes ||
              counters[2] + bytes.length > knowledgePackMaxTotalBytes) {
            counters[1]++;
          } else {
            output.add(
              await createLocalKnowledgeFile(
                relativePath: relative,
                bytes: bytes,
              ),
            );
            counters[2] += bytes.length;
          }
        }
        _showPackProgress(
          KnowledgeDirectoryProgress(
            processed: counters[0],
            compatible: output.length,
            ignored: counters[1],
          ),
        );
      }
    }
  }

  Future<void> _reviewAndUploadPack(
    KnowledgeDirectorySelection selection,
  ) async {
    final draft = await showDialog<KnowledgePackDraft>(
      context: context,
      builder: (context) => KnowledgePackDialog(
        files: selection.files,
        ignoredCount: selection.ignoredCount,
        tx: _tx,
      ),
    );
    if (draft == null || !mounted) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    final pack = await showDialog<KnowledgePack>(
      context: context,
      barrierDismissible: false,
      builder: (context) => KnowledgePackUploadProgressDialog(
        repository: _repository,
        token: token,
        draft: draft,
        tx: _tx,
      ),
    );
    if (pack != null && mounted) {
      final ignored = selection.ignoredCount;
      showMessage(
        (ignored > 0
                ? _tx(
                    'knowledge.pack_uploaded_with_ignored',
                    'Pack incluido: {{name}} · {{included}} archivos · {{ignored}} omitidos',
                  )
                : _tx('knowledge.pack_uploaded', 'Pack incluido: {{name}}'))
            .replaceAll('{{name}}', pack.name)
            .replaceAll('{{included}}', '${pack.fileCount}')
            .replaceAll('{{ignored}}', '$ignored'),
      );
    }
  }

  Future<void> _synchronizePack(KnowledgePack pack) async {
    refresh(() {
      _uploading = true;
      _packOperationMessage = _tx(
        'knowledge.pack_selecting_directory_sync',
        'Selecciona de nuevo el directorio del pack',
      );
    });
    KnowledgeDirectorySelection? selection;
    try {
      selection = await pickKnowledgeDirectory(onProgress: _showPackProgress);
      if (selection == null || !mounted) return;
      if (selection.files.isEmpty) {
        showMessage(
          _tx(
            'knowledge.pack_no_compatible_files',
            'El directorio no contiene archivos de conocimiento compatibles.',
          ),
          isError: true,
        );
        return;
      }
      final confirmed = await showConfirmActionDialog(
        context,
        title: _tx(
          'knowledge.pack_sync_confirm_title',
          'Sincronizar directorio',
        ),
        message: _tx(
          'knowledge.pack_sync_confirm_body',
          'Se compararán {{count}} archivos con el pack. Los archivos que ya no estén en el directorio se eliminarán del pack.',
        ).replaceAll('{{count}}', '${selection.files.length}'),
        confirmLabel: _tx('knowledge.pack_sync_action', 'Sincronizar'),
        cancelLabel: _tx('common.cancel', 'Cancelar'),
      );
      if (!confirmed || !mounted) return;
      final token = _token;
      if (token == null || token.isEmpty) return;
      refresh(() {
        _packOperationMessage = _tx(
          'knowledge.pack_synchronizing',
          'Sincronizando altas, cambios y eliminaciones…',
        );
      });
      final updated = await _repository.synchronizePack(
        token,
        pack: pack,
        files: selection.files,
      );
      final sync = updated.raw['sync'] as Map<String, dynamic>? ?? const {};
      showMessage(
        _tx(
              'knowledge.pack_sync_complete',
              'Pack sincronizado · {{added}} nuevos · {{updated}} actualizados · {{removed}} eliminados',
            )
            .replaceAll('{{added}}', '${sync['added'] ?? 0}')
            .replaceAll('{{updated}}', '${sync['updated'] ?? 0}')
            .replaceAll('{{removed}}', '${sync['removed'] ?? 0}'),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx(
          'knowledge.pack_sync_failed',
          'No se pudo sincronizar el directorio',
        ),
        isError: true,
      );
    } finally {
      if (mounted) {
        refresh(() {
          _uploading = false;
          _packOperationMessage = null;
        });
      }
    }
  }

  Future<void> _sharePack(KnowledgePack pack) async {
    final token = _token;
    if (token == null || token.isEmpty) return;
    await showShareToGroupDialog(
      context: context,
      apiClient: _services.apiClient,
      token: token,
      resourceType: 'knowledge_pack',
      resourceId: pack.id,
      localeController: _services.localeController,
      onShared: _load,
    );
  }

  Future<void> _editPack(KnowledgePack pack) async {
    final result = await _showKnowledgeEditDialog(
      context,
      initialName: pack.name,
      initialDescription: pack.description,
      initialLabels: pack.labels.toSet(),
      isPack: true,
      tx: _tx,
    );
    if (result == null || !mounted) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.updatePack(
        token,
        pack.id,
        name: result.name,
        description: result.description ?? '',
        labels: result.labels.toList(),
      );
      showMessage(_tx('knowledge.edit_saved', 'Cambios guardados'));
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('knowledge.edit_failed', 'No se pudieron guardar los cambios'),
        isError: true,
      );
    }
  }

  Future<void> _deletePack(KnowledgePack pack) async {
    final confirmed = await showConfirmActionDialog(
      context,
      title: _tx('knowledge.pack_delete_title', 'Eliminar pack'),
      message: _tx(
        'knowledge.pack_delete_confirm',
        'Se eliminarán el pack y todos sus archivos. ¿Continuar?',
      ),
      confirmLabel: _tx('common.delete', 'Eliminar'),
      cancelLabel: _tx('common.cancel', 'Cancelar'),
      destructive: true,
    );
    if (!confirmed) return;
    final token = _token;
    if (token == null || token.isEmpty) return;
    try {
      await _repository.deletePack(token, pack.id);
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    }
  }
}
