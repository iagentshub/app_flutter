import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Cabecera de colección: contexto y, debajo, una única barra con la búsqueda,
/// las acciones y el botón de crear.
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
    this.sectionSpacing = 12,
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
    // La acción principal vive dentro de la barra, junto al resto de acciones:
    // una sola fila de controles en todas las pestañas.
    final hasHeading = title != null || description != null || summary != null;
    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null || summary != null)
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (title != null)
                Text(title!, style: theme.textTheme.titleLarge),
              if (summary != null) _summary(context),
            ],
          ),
        if (description != null) ...[
          if (title != null || summary != null) const SizedBox(height: 6),
          Text(
            description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasHeading) ...[heading, const SizedBox(height: 12)],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.65),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LayoutBuilder(
            builder: (context, inner) {
              final hasActions = actions.isNotEmpty || primaryAction != null;
              final inline =
                  kIsWeb &&
                  inner.maxWidth / MediaQuery.textScalerOf(context).scale(1) >=
                      760;
              final searchWidth = inline
                  ? (inner.maxWidth * 0.45).clamp(260.0, 420.0)
                  : inner.maxWidth;
              // El buscador conserva su rama al redimensionar para no perder
              // el foco ni la selección al pasar de una fila a dos.
              return Wrap(
                spacing: sectionSpacing,
                runSpacing: hasActions ? sectionSpacing : 0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: inline && search != null
                        ? inner.maxWidth - searchWidth - sectionSpacing
                        : inner.maxWidth,
                    child: Wrap(
                      alignment: WrapAlignment.start,
                      spacing: actionSpacing,
                      runSpacing: actionSpacing,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [?primaryAction, ...actions],
                    ),
                  ),
                  if (search != null)
                    SizedBox(
                      width: searchWidth,
                      child: Theme(
                        data: theme.copyWith(
                          textTheme: theme.textTheme.copyWith(
                            bodyLarge: theme.textTheme.bodyMedium,
                          ),
                          inputDecorationTheme: theme.inputDecorationTheme
                              .copyWith(
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                              ),
                        ),
                        child: search!,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (activeFilters.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: activeFilters),
        ],
      ],
    );
  }

  Widget _summary(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(6),
    ),
    child: DefaultTextStyle.merge(
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      child: summary!,
    ),
  );
}
