import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../models/knowledge/knowledge_models.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../models/local_knowledge_file.dart';
import '../repositories/knowledge_repository.dart';
import 'knowledge_pack_dialog.dart';

enum _PackFileUploadStatus { pending, uploading, uploaded, failed }

class _PackFileUploadState {
  _PackFileUploadState(this.file);

  final LocalKnowledgeFile file;
  _PackFileUploadStatus status = _PackFileUploadStatus.pending;
  double progress = 0;
  String error = '';
}

class KnowledgePackUploadProgressDialog extends StatefulWidget {
  const KnowledgePackUploadProgressDialog({
    required this.repository,
    required this.token,
    required this.draft,
    required this.tx,
    super.key,
  });

  final KnowledgeRepository repository;
  final String token;
  final KnowledgePackDraft draft;
  final String Function(String path) tx;

  @override
  State<KnowledgePackUploadProgressDialog> createState() =>
      _KnowledgePackUploadProgressDialogState();
}

class _KnowledgePackUploadProgressDialogState
    extends State<KnowledgePackUploadProgressDialog> {
  late final List<_PackFileUploadState> _files;
  String? _sessionId;
  KnowledgePack? _completedPack;
  String _fatalError = '';
  bool _running = true;
  bool _finishing = false;

  int get _uploaded => _files
      .where((item) => item.status == _PackFileUploadStatus.uploaded)
      .length;
  int get _failed => _files
      .where((item) => item.status == _PackFileUploadStatus.failed)
      .length;
  int get _attempted => _files
      .where(
        (item) =>
            item.status != _PackFileUploadStatus.pending &&
            item.status != _PackFileUploadStatus.uploading,
      )
      .length;
  int get _visibleCounter =>
      _attempted +
      (_files.any((e) => e.status == _PackFileUploadStatus.uploading) ? 1 : 0);

  @override
  void initState() {
    super.initState();
    _files = widget.draft.files.map(_PackFileUploadState.new).toList();
    _start();
  }

  String _message(Object error) => error is ApiError
      ? error.message
      : widget.tx('knowledge.pack_file_unknown_error');

  Future<void> _start() async {
    try {
      final session = await widget.repository.createPackUploadSession(
        widget.token,
        name: widget.draft.name,
        description: widget.draft.description,
        sourceMode: widget.draft.sourceMode,
        labels: widget.draft.labels.toList(),
        totalFiles: _files.length,
      );
      if (!mounted) return;
      _sessionId = session.id;
      await _upload(_files);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fatalError = _message(error);
        _running = false;
      });
    }
  }

  Future<void> _upload(List<_PackFileUploadState> queue) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    setState(() => _running = true);
    for (final item in queue) {
      if (!mounted) return;
      setState(() {
        item.status = _PackFileUploadStatus.uploading;
        item.progress = 0;
        item.error = '';
      });
      try {
        await widget.repository.uploadPackSessionFile(
          widget.token,
          sessionId: sessionId,
          file: item.file,
          referenceOnly: widget.draft.sourceMode == 'reference',
          onProgress: (progress) {
            if (!mounted) return;
            setState(() => item.progress = progress);
          },
        );
        if (!mounted) return;
        setState(() {
          item.status = _PackFileUploadStatus.uploaded;
          item.progress = 1;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          item.status = _PackFileUploadStatus.failed;
          item.error = _message(error);
        });
      }
    }
    if (!mounted) return;
    setState(() => _running = false);
    if (_failed == 0) await _finish();
  }

  Future<void> _retryFailed() async {
    final failed = _files
        .where((item) => item.status == _PackFileUploadStatus.failed)
        .toList();
    await _upload(failed);
  }

  Future<void> _finish() async {
    final sessionId = _sessionId;
    if (sessionId == null || _uploaded == 0) return;
    setState(() => _finishing = true);
    try {
      final pack = await widget.repository.completePackUploadSession(
        widget.token,
        sessionId,
      );
      if (!mounted) return;
      setState(() {
        _completedPack = pack;
        _finishing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _fatalError = _message(error);
        _finishing = false;
      });
    }
  }

  Future<void> _cancel() async {
    final sessionId = _sessionId;
    if (sessionId != null) {
      try {
        await widget.repository.cancelPackUploadSession(
          widget.token,
          sessionId,
        );
      } catch (_) {
        // La sesión incompleta no se muestra en Conocimiento y puede limpiarse después.
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final total = _files.length;
    final overall = total == 0 ? 0.0 : (_attempted / total).clamp(0.0, 1.0);
    final done = _completedPack != null;
    return PopScope(
      canPop: done || (!_running && !_finishing),
      child: AlertDialog(
        title: Text(widget.tx('knowledge.pack_upload_progress_title')),
        content: SizedBox(
          width: dialogContentWidth(context, 680),
          height: MediaQuery.sizeOf(context).height.clamp(360, 660) * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      done
                          ? widget.tx('knowledge.pack_upload_complete')
                          : widget.tx('knowledge.pack_upload_processing'),
                    ),
                  ),
                  Text('$_visibleCounter/$total'),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: done ? 1 : overall),
              const SizedBox(height: 8),
              Text(
                widget
                    .tx('knowledge.pack_upload_summary')
                    .replaceAll('{{ok}}', '$_uploaded')
                    .replaceAll('{{failed}}', '$_failed')
                    .replaceAll(
                      '{{pending}}',
                      '${total - _uploaded - _failed}',
                    ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_fatalError.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _fatalError,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _files.length,
                  itemExtent: null,
                  itemBuilder: (context, index) =>
                      _FileProgressRow(state: _files[index], tx: widget.tx),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (done)
            PrimaryButton(
              onPressed: () => Navigator.of(context).pop(_completedPack),
              child: Text(widget.tx('common.close')),
            )
          else if (!_running && !_finishing) ...[
            TertiaryButton(
              onPressed: _cancel,
              child: Text(widget.tx('common.cancel')),
            ),
            if (_failed > 0)
              SecondaryButton(
                onPressed: _retryFailed,
                child: Text(widget.tx('knowledge.pack_retry_failed')),
              ),
            if (_uploaded > 0 && _failed > 0)
              PrimaryButton(
                onPressed: _finish,
                child: Text(widget.tx('knowledge.pack_finish_without_failed')),
              ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }
}

class _FileProgressRow extends StatelessWidget {
  const _FileProgressRow({required this.state, required this.tx});

  final _PackFileUploadState state;
  final String Function(String path) tx;

  @override
  Widget build(BuildContext context) {
    final failed = state.status == _PackFileUploadStatus.failed;
    final value = switch (state.status) {
      _PackFileUploadStatus.pending => 0.0,
      _PackFileUploadStatus.uploading => state.progress,
      _ => 1.0,
    };
    final status = switch (state.status) {
      _PackFileUploadStatus.pending => tx('common.pending'),
      _PackFileUploadStatus.uploading => tx('common.uploading'),
      _PackFileUploadStatus.uploaded => tx('common.completed'),
      _PackFileUploadStatus.failed => tx('common.error'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  state.file.relativePath,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(status, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: value,
            color: failed ? Theme.of(context).colorScheme.error : null,
          ),
          if (failed && state.error.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              state.error,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
