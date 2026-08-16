part of '../pages/knowledge_page.dart';

extension _DocumentActions on _KnowledgePageState {
  Future<void> _uploadDocument({bool imageOnly = false}) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    refresh(() {
      _uploading = true;
      _packOperationMessage = _tx(
        'knowledge.document_selecting',
        'Selecciona el documento',
      );
    });
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        withData: true,
        type: imageOnly ? FileType.image : FileType.any,
        onFileLoading: (status) {
          if (!mounted) return;
          refresh(() {
            _packOperationMessage = status == FilePickerStatus.picking
                ? _tx('knowledge.document_reading', 'Leyendo el documento…')
                : _tx(
                    'knowledge.document_preparing',
                    'Preparando el documento…',
                  );
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _uploading = false;
        _packOperationMessage = null;
      });
      showMessage(
        _tx(
          'knowledge.document_pick_failed',
          'No se pudo abrir o leer el documento seleccionado',
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
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (!isSupportedKnowledgePackPath(file.name)) {
      showMessage(
        _tx(
          'knowledge.document_unsupported',
          'Este formato no se puede convertir en conocimiento',
        ),
        isError: true,
      );
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showMessage(
        _tx(
          'knowledge.msg_file_unreadable',
          'No se pudieron leer los bytes del fichero',
        ),
        isError: true,
      );
      return;
    }
    if (bytes.length > knowledgePackMaxFileBytes) {
      showMessage(
        _tx(
          'knowledge.document_too_large',
          'El documento supera el límite de 10 MB',
        ),
        isError: true,
      );
      return;
    }

    final labels = await _showContentLabelsDialog(context, tx: _tx);
    if (labels == null || !mounted) return;

    refresh(() {
      _uploading = true;
      _packOperationMessage = _tx(
        'knowledge.document_uploading',
        'Subiendo e indexando el documento…',
      );
    });
    try {
      await _repository.uploadDocument(
        token,
        fileName: file.name,
        fileBytes: bytes,
        labels: labels.toList(),
      );
      showMessage(
        _tx(
          'knowledge.msg_document_uploaded',
          'Documento subido: {{nombre}}',
        ).replaceAll('{{nombre}}', file.name),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(
        _tx('knowledge.msg_upload_failed', 'No se pudo subir el documento'),
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
}
