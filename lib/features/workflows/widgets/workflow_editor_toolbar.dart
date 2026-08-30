import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

class WorkflowEditorToolbar extends StatelessWidget {
  const WorkflowEditorToolbar({
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
    this.onIssuesPressed,
    super.key,
  });

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
  final VoidCallback? onIssuesPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final metrics = Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$stepCount $stepsLabel · $connectionCount $connectionsLabel',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (issueCount > 0)
          TertiaryButton.icon(
            key: const ValueKey('workflow-issues-button'),
            onPressed: onIssuesPressed,
            style: TextButton.styleFrom(
              foregroundColor: colors.error,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.error_outline_rounded, size: 17),
            label: Text('$issueCount $issuesLabel'),
          ),
      ],
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (onAutoLayout != null)
          TertiaryButton.icon(
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
        final compact = constraints.maxWidth < 560;
        return Padding(
          key: const ValueKey('workflow-editor-toolbar'),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 8,
          ),
          child: Row(
            children: [
              Expanded(child: metrics),
              const SizedBox(width: 8),
              if (compact) ...[
                if (onAutoLayout != null)
                  AppIconButton(
                    onPressed: onAutoLayout,
                    tooltip: autoLayoutLabel,
                    icon: const Icon(
                      Icons.auto_awesome_mosaic_outlined,
                      size: 19,
                    ),
                  ),
                const SizedBox(width: 4),
                AppIconButton.filledTonal(
                  onPressed: onAdd,
                  tooltip: addLabel,
                  icon: const Icon(Icons.add_rounded),
                ),
              ] else
                actions,
            ],
          ),
        );
      },
    );
  }
}
