import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

class WorkflowEditorToolbar extends StatelessWidget {
  const WorkflowEditorToolbar({
    required this.title,
    required this.subtitle,
    required this.stepCount,
    required this.connectionCount,
    required this.stepsLabel,
    required this.connectionsLabel,
    required this.addLabel,
    required this.onAdd,
    this.issueCount = 0,
    this.issuesLabel = '',
    this.autoLayoutLabel = '',
    this.onAutoLayout,
    super.key,
  });

  final String title;
  final String subtitle;
  final int stepCount;
  final int connectionCount;
  final String stepsLabel;
  final String connectionsLabel;
  final String addLabel;
  final VoidCallback onAdd;
  final int issueCount;
  final String issuesLabel;
  final String autoLayoutLabel;
  final VoidCallback? onAutoLayout;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _EditorMetric(value: stepCount, label: stepsLabel),
        _EditorMetric(value: connectionCount, label: connectionsLabel),
        if (issueCount > 0)
          _EditorMetric(
            value: issueCount,
            label: issuesLabel,
            color: colors.error,
          ),
        if (onAutoLayout != null)
          SecondaryButton.icon(
            onPressed: onAutoLayout,
            icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 18),
            label: Text(autoLayoutLabel),
          ),
        PrimaryButton.tonalIcon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded),
          label: Text(addLabel),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [heading, const SizedBox(height: 12), actions],
          );
        }
        // `actions` es un `Wrap`, y un hijo no flexible de un `Row` recibe
        // ancho **no acotado**: así el Wrap no envuelve nunca, se estira a lo
        // que pidan los botones y al `Expanded` del título le quedan las
        // migas, con lo que su texto envuelve casi letra a letra. Medido a
        // 1024 px de ventana: la barra pedía 1139 px de alto en vez de ~50, se
        // comía la columna del editor y la dejaba desbordada por abajo.
        return Row(
          children: [
            Expanded(child: heading),
            const SizedBox(width: 20),
            Flexible(child: actions),
          ],
        );
      },
    );
  }
}

class _EditorMetric extends StatelessWidget {
  const _EditorMetric({required this.value, required this.label, this.color});

  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final accent = color ?? colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color == null
            ? colors.surfaceContainerHigh
            : color!.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$value $label',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
