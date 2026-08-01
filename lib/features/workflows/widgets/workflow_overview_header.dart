import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

class WorkflowOverviewHeader extends StatelessWidget {
  const WorkflowOverviewHeader({
    required this.createLabel,
    required this.onCreate,
    super.key,
  });

  final String createLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: PrimaryButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded, size: 18),
        label: Text(createLabel),
      ),
    );
  }
}

class WorkflowEmptyState extends StatelessWidget {
  const WorkflowEmptyState({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onCreate,
    super.key,
  });

  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.hub_outlined, color: colors.primary, size: 28),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
