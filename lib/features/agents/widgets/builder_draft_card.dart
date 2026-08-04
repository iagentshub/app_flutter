import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

/// Borrador propuesto por el constructor por IA, presentado al final de la
/// conversación. El formulario de revisión sólo se abre si el usuario lo pide:
/// nada se despliega solo encima del chat.
class BuilderDraftCard extends StatelessWidget {
  const BuilderDraftCard({
    required this.draft,
    required this.title,
    required this.actionLabel,
    required this.onReview,
    super.key,
  });

  final Map<String, dynamic> draft;
  final String title;
  final String actionLabel;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final name = (draft['name'] as String? ?? '').trim();
    final description = (draft['description'] as String? ?? '').trim();

    return Container(
      key: const ValueKey('builder-draft-card'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              name,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
          if (description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: PrimaryButton(
              onPressed: onReview,
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
