import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../models/workflow_run_state.dart';
import '../models/workflow_step_draft.dart';

String formatRunDuration(Duration value) {
  if (value.inMinutes >= 1) {
    final seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return '${value.inMinutes}m ${seconds}s';
  }
  if (value.inSeconds >= 10) return '${value.inSeconds}s';
  return '${(value.inMilliseconds / 1000).toStringAsFixed(1)}s';
}

Color runStatusColor(BuildContext context, RunNodeStatus status) {
  final colors = Theme.of(context).colorScheme;
  return switch (status) {
    RunNodeStatus.waiting => colors.outline,
    RunNodeStatus.running => colors.primary,
    RunNodeStatus.done => FncColors.materialGreen.shade600,
    RunNodeStatus.error => colors.error,
  };
}

/// Panel derecho del visor de ejecución: todo lo que el motor cuenta sobre el
/// nodo seleccionado, incluido el veredicto del evaluador que antes se tiraba.
class WorkflowRunDetailCard extends StatelessWidget {
  const WorkflowRunDetailCard({
    required this.state,
    required this.steps,
    required this.selectedStepId,
    required this.agentNameFor,
    required this.tx,
    super.key,
  });

  final WorkflowRunState state;
  final List<WorkflowStepDraft> steps;
  final String? selectedStepId;
  final String Function(String agentId) agentNameFor;
  final String Function(String path, String fallback) tx;

  WorkflowStepDraft? get _step => steps.byId(selectedStepId ?? '');

  String _stepTitle(WorkflowStepDraft step) =>
      step.label.trim().isEmpty ? agentNameFor(step.agentId) : step.label;

  String _statusLabel(RunNodeStatus status) => switch (status) {
    RunNodeStatus.waiting => tx('workflows.node_waiting', 'Pendiente'),
    RunNodeStatus.running => tx('workflows.node_running', 'En curso'),
    RunNodeStatus.done => tx('workflows.node_done', 'Completado'),
    RunNodeStatus.error => tx('workflows.run_status_error', 'Error'),
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final step = _step;
    final body = _bodyText(step);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, step, body),
          const SizedBox(height: 10),
          // Todo lo de debajo comparte un solo scroll: chips, veredicto,
          // salida y registro pueden coincidir y no caben a la vez en el
          // panel.
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (step != null) ...[
                  _metaChips(context, step),
                  _evaluatorVerdict(context, step),
                ],
                const SizedBox(height: 14),
                if (body == null || body.trim().isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      state.running
                          ? tx(
                              'workflows.node_output_waiting',
                              'Aquí aparecerá el resultado de este paso.',
                            )
                          : tx(
                              'workflows.no_output',
                              'Sin resultado disponible',
                            ),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  )
                else
                  SelectableText(
                    body,
                    style: TextStyle(
                      height: 1.5,
                      color: state.error != null && step == null
                          ? colors.error
                          : colors.onSurface,
                    ),
                  ),
                if (state.timeline.isNotEmpty) _timeline(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _bodyText(WorkflowStepDraft? step) {
    if (step == null) return state.error ?? state.finalOutput;
    return state.outputs[step.id];
  }

  Widget _header(BuildContext context, WorkflowStepDraft? step, String? body) {
    final colors = Theme.of(context).colorScheme;
    final isError = state.error != null && step == null;
    final title = step == null
        ? (state.running
              ? tx(
                  'workflows.run_waiting_first_event',
                  'Preparando la orquestación…',
                )
              : tx('workflows.final_output_title', 'Resultado final'))
        : _stepTitle(step);

    return Row(
      children: [
        Icon(
          isError
              ? Icons.error_outline
              : step == null
              ? Icons.flag_outlined
              : Icons.notes_rounded,
          size: 19,
          color: isError ? colors.error : colors.primary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (body != null && body.trim().isNotEmpty)
          AppIconButton(
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: tx('workflows.copy_output', 'Copiar resultado'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: body));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(tx('workflows.copied', 'Copiado')),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _metaChips(BuildContext context, WorkflowStepDraft step) {
    final status = state.status[step.id] ?? RunNodeStatus.waiting;
    final duration = state.durations[step.id];
    final iteration = state.iterations[step.id] ?? 1;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _Chip(
          label: _statusLabel(status),
          color: runStatusColor(context, status),
        ),
        if (duration != null)
          _Chip(
            label: formatRunDuration(duration),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            icon: Icons.timer_outlined,
          ),
        if (iteration > 1)
          _Chip(
            label: tx(
              'workflows.loop_round',
              'Vuelta {{n}}',
            ).replaceAll('{{n}}', '$iteration'),
            color: Theme.of(context).colorScheme.tertiary,
            icon: Icons.refresh_rounded,
          ),
      ],
    );
  }

  Widget _evaluatorVerdict(BuildContext context, WorkflowStepDraft step) {
    final approved = state.evaluatorApproved[step.id];
    if (approved == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final accent = approved
        ? FncColors.materialGreen.shade600
        : colors.tertiary;
    final reason = state.evaluatorReasons[step.id];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: .40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  approved ? Icons.verified_outlined : Icons.replay_rounded,
                  size: 17,
                  color: accent,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    approved
                        ? tx(
                            'workflows.evaluator_approved',
                            'Condición cumplida',
                          )
                        : tx(
                            'workflows.evaluator_rejected',
                            'Rechazado: repite el ciclo',
                          ),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (reason != null && reason.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              SelectableText(
                reason,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurface,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Reaprovecha las claves `workflows.event_*` que ya existen en el bundle.
  String _eventLabel(RunTimelineEntry entry) => switch (entry.type) {
    'stage_started' => tx('workflows.event_stage_started', 'Paso iniciado'),
    'stage_done' => tx('workflows.event_stage_done', 'Paso completado'),
    'evaluation_started' => tx(
      'workflows.event_evaluation_started',
      'Evaluando',
    ),
    'evaluation_done' =>
      entry.approved == true
          ? tx('workflows.event_evaluation_approved', 'Evaluación aprobada')
          : tx('workflows.event_evaluation_rejected', 'Evaluación rechazada'),
    'loop_iteration_started' => tx(
      'workflows.event_loop_iteration',
      'Nueva vuelta del ciclo',
    ),
    'loop_limit_reached' => tx(
      'workflows.event_loop_limit',
      'Límite de vueltas alcanzado',
    ),
    'workflow_done' => tx(
      'workflows.event_workflow_done',
      'Orquestación lista',
    ),
    'cancelled' => tx('workflows.run_cancelled', 'Cancelada'),
    'error' => tx('workflows.run_status_error', 'Error'),
    _ => entry.type,
  };

  Widget _timeline(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      // El panel es un Container decorado; sin este Material el ListTile de
      // ExpansionTile no encuentra dónde pintar su ink.
      type: MaterialType.transparency,
      child: Theme(
        data: Theme.of(
          context,
        ).copyWith(dividerColor: FncColors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 4),
          dense: true,
          title: Text(
            '${tx('workflows.timeline_title', 'Registro de eventos')} '
            '(${state.timeline.length})',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colors.onSurfaceVariant),
          ),
          children: [
            // Más reciente arriba.
            for (final entry in state.timeline.reversed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(
                        formatRunDuration(entry.at),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        [
                          _eventLabel(entry),
                          if (entry.label != null) '· ${entry.label}',
                        ].join(' '),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: FncFonts.size12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
