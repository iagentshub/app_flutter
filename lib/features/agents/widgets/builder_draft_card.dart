import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';

/// Borrador propuesto por el constructor por IA, al final de la conversación.
///
/// Es un bloque plano separado por una línea, no una tarjeta: cierra la
/// transcripción sin robarle protagonismo. El formulario de revisión sólo se
/// abre si el usuario pulsa la acción.
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
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    letterSpacing: 0.4,
                  ),
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          PrimaryButton(onPressed: onReview, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
