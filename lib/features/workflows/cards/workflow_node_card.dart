import 'package:flutter/material.dart';

import '../models/workflow_step_draft.dart';

/// Estado visual de un nodo dentro del lienzo.
///
/// `none` es el modo edición; el resto refleja lo que está haciendo el motor
/// durante una ejecución en vivo.
enum WorkflowNodeVisualStatus { none, waiting, running, done, error }

/// Nodo dibujado dentro de `WorkflowVisualCanvas`.
///
/// El mismo widget sirve para el editor y para el visor de ejecución: en el
/// editor marca selección y errores de validación, y durante un run pinta el
/// estado que llega por SSE.
class WorkflowNodeCard extends StatelessWidget {
  const WorkflowNodeCard({
    required this.step,
    required this.agentName,
    required this.agentKindLabel,
    required this.evaluatorKindLabel,
    this.selected = false,
    this.hasIssue = false,
    this.status = WorkflowNodeVisualStatus.none,
    this.iteration = 1,
    super.key,
  });

  final WorkflowStepDraft step;
  final String agentName;
  final String agentKindLabel;
  final String evaluatorKindLabel;
  final bool selected;
  final bool hasIssue;
  final WorkflowNodeVisualStatus status;
  final int iteration;

  Color _accent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (hasIssue) return colors.error;
    return switch (status) {
      WorkflowNodeVisualStatus.waiting => colors.outline,
      WorkflowNodeVisualStatus.running => colors.primary,
      WorkflowNodeVisualStatus.done => Colors.green.shade600,
      WorkflowNodeVisualStatus.error => colors.error,
      WorkflowNodeVisualStatus.none =>
        step.isEvaluator ? colors.tertiary : colors.primary,
    };
  }

  bool get _highlighted =>
      selected ||
      hasIssue ||
      status == WorkflowNodeVisualStatus.running ||
      status == WorkflowNodeVisualStatus.error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = _accent(context);
    final label = step.label.trim().isEmpty ? agentName : step.label;

    return AnimatedContainer(
      key: ValueKey('workflow-node-${step.id}'),
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(
        color: status == WorkflowNodeVisualStatus.waiting
            ? colors.surfaceContainerLow
            : colors.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _highlighted ? accent : colors.outlineVariant,
          width: _highlighted ? 2 : 1,
        ),
        boxShadow: [
          if (_highlighted)
            BoxShadow(
              color: accent.withValues(alpha: .16),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _NodeGlyph(
                accent: accent,
                status: status,
                evaluator: step.isEvaluator,
                hasIssue: hasIssue,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (iteration > 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '×$iteration',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            agentName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const Spacer(),
          Text(
            (step.isEvaluator ? evaluatorKindLabel : agentKindLabel)
                .toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeGlyph extends StatelessWidget {
  const _NodeGlyph({
    required this.accent,
    required this.status,
    required this.evaluator,
    required this.hasIssue,
  });

  final Color accent;
  final WorkflowNodeVisualStatus status;
  final bool evaluator;
  final bool hasIssue;

  IconData get _icon {
    if (hasIssue) return Icons.priority_high_rounded;
    return switch (status) {
      WorkflowNodeVisualStatus.done => Icons.check_rounded,
      WorkflowNodeVisualStatus.error => Icons.priority_high_rounded,
      _ => evaluator ? Icons.rule_rounded : Icons.smart_toy_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .15),
        borderRadius: BorderRadius.circular(9),
      ),
      child: status == WorkflowNodeVisualStatus.running
          ? Padding(
              padding: const EdgeInsets.all(8),
              child: CircularProgressIndicator(strokeWidth: 2.4, color: accent),
            )
          : Icon(_icon, size: 18, color: accent),
    );
  }
}
