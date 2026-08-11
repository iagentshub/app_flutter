import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../models/official_import_models.dart';

class OfficialImportProgressDialog extends StatefulWidget {
  const OfficialImportProgressDialog({
    required this.events,
    required this.tx,
    super.key,
  });

  final Stream<OfficialImportEvent> events;
  final String Function(String, String) tx;

  @override
  State<OfficialImportProgressDialog> createState() =>
      _OfficialImportProgressDialogState();
}

class _OfficialImportProgressDialogState
    extends State<OfficialImportProgressDialog> {
  StreamSubscription<OfficialImportEvent>? subscription;
  Timer? elapsedTimer;
  OfficialImportProgress progress = const OfficialImportProgress(
    stage: 'starting',
  );
  final List<String> completedStages = [];
  final List<String> activity = [];
  Duration elapsed = Duration.zero;
  String? error;
  bool receivedResult = false;

  @override
  void initState() {
    super.initState();
    elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => elapsed = Duration(seconds: timer.tick));
      }
    });
    subscription = widget.events.listen(
      (event) {
        if (!mounted) return;
        if (event.draft != null) {
          receivedResult = true;
          Navigator.of(context).pop(event.draft);
          return;
        }
        if (event.error != null) {
          _setError(event.error!);
          return;
        }
        final next = event.progress;
        if (next == null) return;
        setState(() {
          if (progress.stage != next.stage &&
              progress.stage != 'starting' &&
              progress.stage != 'llm_analyzing' &&
              progress.stage != 'llm_chunk_failed') {
            completedStages.add(_stageLabel(progress.stage));
          }
          progress = next;
          activity.addAll(_activityFor(next));
          if (activity.length > 200) {
            activity.removeRange(0, activity.length - 200);
          }
        });
      },
      onError: (Object value) {
        if (mounted) _setError(value.toString());
      },
      onDone: () {
        if (mounted && error == null && !receivedResult) {
          _setError(
            widget.tx(
              'official.progress_interrupted',
              'El análisis terminó sin devolver un borrador.',
            ),
          );
        }
      },
    );
  }

  void _setError(String value) {
    elapsedTimer?.cancel();
    setState(() {
      error = value;
      activity.add(value);
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    elapsedTimer?.cancel();
    super.dispose();
  }

  List<String> _activityFor(OfficialImportProgress value) {
    if (value.stage == 'llm_analyzing') {
      final paths = value.paths.isEmpty ? '' : ': ${value.paths.join(', ')}';
      return [
        widget
            .tx(
              'official.progress_log_analyzing',
              'Fragmento {current}/{total}: revisando {files} archivos{paths}',
            )
            .replaceAll('{current}', '${value.current}')
            .replaceAll('{total}', '${value.total}')
            .replaceAll('{files}', '${value.files}')
            .replaceAll('{paths}', paths),
      ];
    }
    if (value.stage == 'llm_chunk_complete') {
      return [
        widget
            .tx(
              'official.progress_log_complete',
              'Fragmento {current}/{total}: {components} candidatos y {relations} relaciones',
            )
            .replaceAll('{current}', '${value.current}')
            .replaceAll('{total}', '${value.total}')
            .replaceAll('{components}', '${value.chunkComponents}')
            .replaceAll('{relations}', '${value.chunkRelations}'),
        for (final finding in value.findings)
          widget
              .tx(
                'official.progress_log_finding',
                'Detectado {type}: {name} · {path}',
              )
              .replaceAll('{type}', finding.resourceType)
              .replaceAll('{name}', finding.name)
              .replaceAll('{path}', finding.sourcePath),
      ];
    }
    return [_stageLabel(value.stage)];
  }

  String get elapsedLabel {
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = elapsed.inHours;
    return hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  String _stageLabel(String stage) => switch (stage) {
    'downloading' => widget.tx(
      'official.progress_downloading',
      'Descargando el repositorio fijado a commit',
    ),
    'detecting' => widget.tx(
      'official.progress_detecting',
      'Reconociendo archivos y candidatos',
    ),
    'llm_preparing' => widget.tx(
      'official.progress_preparing',
      'Preparando el análisis semántico',
    ),
    'llm_analyzing' => widget.tx(
      'official.progress_analyzing',
      'El LLM está analizando el repositorio',
    ),
    'llm_chunk_complete' => widget.tx(
      'official.progress_chunk_complete',
      'Fragmento analizado',
    ),
    'llm_retrying' => widget.tx(
      'official.progress_retrying',
      'Corrigiendo el formato de respuesta del LLM',
    ),
    'llm_chunk_failed' => widget.tx(
      'official.progress_chunk_failed',
      'Fragmento omitido; el análisis continúa',
    ),
    'validating' => widget.tx(
      'official.progress_validating',
      'Validando rutas, relaciones y seguridad',
    ),
    'saving_draft' => widget.tx(
      'official.progress_saving',
      'Preparando el borrador de revisión',
    ),
    _ => widget.tx('official.progress_starting', 'Iniciando análisis'),
  };

  @override
  Widget build(BuildContext context) {
    final fraction = progress.fraction;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        widget.tx('official.progress_title', 'Analizando repositorio'),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 520, margin: 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value: fraction,
                color: error == null
                    ? null
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      error ?? _stageLabel(progress.stage),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: error == null
                            ? null
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: widget.tx('official.progress_elapsed', 'Tiempo'),
                    child: Text(
                      elapsedLabel,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              if (error == null && progress.total > 0) ...[
                const SizedBox(height: 6),
                Text(
                  widget
                      .tx(
                        'official.progress_chunk',
                        'Fragmento {current} de {total}',
                      )
                      .replaceAll('{current}', '${progress.current}')
                      .replaceAll('{total}', '${progress.total}'),
                ),
              ],
              if (error == null &&
                  (progress.files > 0 || progress.components > 0)) ...[
                const SizedBox(height: 6),
                Text(
                  widget
                      .tx(
                        'official.progress_counts',
                        '{files} archivos · {components} candidatos encontrados',
                      )
                      .replaceAll('{files}', '${progress.files}')
                      .replaceAll('{components}', '${progress.components}'),
                ),
              ],
              if (completedStages.isNotEmpty) ...[
                const SizedBox(height: 16),
                for (final stage in completedStages.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(stage)),
                      ],
                    ),
                  ),
              ],
              if (activity.isNotEmpty)
                ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(
                    '${widget.tx('official.progress_activity', 'Actividad')} '
                    '(${activity.length})',
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 180),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: SelectableText(activity.join('\n')),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (error == null)
          TertiaryButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.tx('common.cancel', 'Cancelar')),
          )
        else
          PrimaryButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.tx('common.close', 'Cerrar')),
          ),
      ],
    );
  }
}
