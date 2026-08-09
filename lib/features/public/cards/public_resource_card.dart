import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../models/explore/explore_models.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/resource_type_badge.dart';

class PublicResourceCard extends StatelessWidget {
  const PublicResourceCard({
    required this.item,
    required this.typeLabel,
    required this.previewTooltip,
    required this.onPreview,
    super.key,
  });

  final ExploreItem item;
  final String typeLabel;
  final String previewTooltip;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 4,
              child: ColoredBox(color: labelColor(item.resourceType)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: FncFonts.size16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ActionIconButton(
                          icon: Icons.visibility_outlined,
                          tooltip: previewTooltip,
                          onPressed: onPreview,
                        ),
                      ],
                    ),
                    if (item.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(height: 1.35),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ResourceTypeBadge(
                          type: item.resourceType,
                          label: typeLabel,
                        ),
                        _MetaChip(label: item.category),
                        _MetaChip(
                          icon: Icons.star,
                          iconColor: FncColors.materialAmber.shade600,
                          label: '${item.stars}',
                        ),
                      ],
                    ),
                    if (item.tags.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final tag in item.tags.take(4))
                            Text(
                              '#$tag',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon, this.iconColor});

  final String label;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(width: 3),
          ],
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
