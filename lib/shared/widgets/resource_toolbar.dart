import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

/// Cabecera de colección: contexto y acción principal, seguida de filtros.
class ResourceToolbar extends StatelessWidget {
  const ResourceToolbar({
    required this.actions,
    this.title,
    this.description,
    this.primaryAction,
    this.search,
    this.summary,
    this.activeFilters = const [],
    this.actionSpacing = 8,
    this.sectionSpacing = 16,
    super.key,
  });

  final String? title;
  final String? description;
  final Widget? primaryAction;
  final Widget? search;
  final List<Widget> actions;
  final Widget? summary;
  final List<Widget> activeFilters;
  final double actionSpacing;
  final double sectionSpacing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasHeading = title != null || primaryAction != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth / MediaQuery.textScalerOf(context).scale(1) <
            620;
        final heading = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) Text(title!, style: theme.textTheme.titleLarge),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (title == null && summary != null) _summary(context),
          ],
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasHeading) ...[
              if (compact)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    if (primaryAction != null) ...[
                      const SizedBox(height: 16),
                      primaryAction!,
                    ],
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: heading),
                    if (primaryAction != null) ...[
                      const SizedBox(width: 24),
                      primaryAction!,
                    ],
                  ],
                ),
              const SizedBox(height: 24),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: FncColors.borderSubtle(context)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: LayoutBuilder(
                builder: (context, inner) {
                  final inline =
                      kIsWeb &&
                      inner.maxWidth /
                              MediaQuery.textScalerOf(context).scale(1) >=
                          760;
                  final searchWidth = inline
                      ? (inner.maxWidth * 0.45).clamp(260.0, 420.0)
                      : inner.maxWidth;
                  // Keep the field in the same branch when resizing so focus
                  // and selection survive desktop/mobile width changes.
                  return Wrap(
                    spacing: sectionSpacing,
                    runSpacing: sectionSpacing,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (search != null)
                        SizedBox(width: searchWidth, child: search),
                      SizedBox(
                        width: inline && search != null
                            ? inner.maxWidth - searchWidth - sectionSpacing
                            : inner.maxWidth,
                        child: Wrap(
                          alignment: inline
                              ? WrapAlignment.end
                              : WrapAlignment.start,
                          spacing: actionSpacing,
                          runSpacing: actionSpacing,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ...actions,
                            if (summary != null &&
                                (!hasHeading || title != null))
                              _summary(context),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (activeFilters.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: activeFilters),
            ],
          ],
        );
      },
    );
  }

  Widget _summary(BuildContext context) => DefaultTextStyle.merge(
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    child: summary!,
  );
}
