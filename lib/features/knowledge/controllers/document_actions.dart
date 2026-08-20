part of '../pages/knowledge_page.dart';

extension _DocumentActions on _KnowledgePageState {
  Future<void> _uploadDocument({bool imageOnly = false}) async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    refresh(() {
      _uploading = true;
      _packOperationMessage = _tx('knowledge.document_selecting');
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
                ? _tx('knowledge.document_reading')
                : _tx('knowledge.document_preparing');
          });
        },
      );
    } catch (_) {
      if (!mounted) return;
      refresh(() {
        _uploading = false;
        _packOperationMessage = null;
      });
      showMessage(_tx('knowledge.document_pick_failed'), isError: true);
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
      showMessage(_tx('knowledge.document_unsupported'), isError: true);
      return;
    }
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      showMessage(_tx('knowledge.msg_file_unreadable'), isError: true);
      return;
    }
    if (excedeElLimiteDeSubida(bytes.length)) {
      showMessage(
        _tx(
          'knowledge.document_too_large',
        ).replaceAll('{limit}', UploadLimits.formatted),
        isError: true,
      );
      return;
    }

    final labels = await _showContentLabelsDialog(context, tx: _tx);
    if (labels == null || !mounted) return;

    refresh(() {
      _uploading = true;
      _packOperationMessage = _tx('knowledge.document_uploading');
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
        ).replaceAll('{{nombre}}', file.name),
      );
    } on ApiError catch (error) {
      showMessage(error.message, isError: true);
    } catch (_) {
      showMessage(_tx('knowledge.msg_upload_failed'), isError: true);
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
