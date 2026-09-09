import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

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
    // La acción principal vive dentro de la barra, junto al resto de acciones:
    // una sola fila de controles en todas las pestañas.
    final hasHeading = title != null || description != null;
    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) Text(title!, style: theme.textTheme.titleLarge),
        if (description != null) ...[
          if (title != null) const SizedBox(height: 8),
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
        if (hasHeading) ...[heading, const SizedBox(height: 24)],
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: FncColors.borderSubtle(context)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: LayoutBuilder(
            builder: (context, inner) {
              final hasActions =
                  actions.isNotEmpty ||
                  primaryAction != null ||
                  summary != null;
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
                      children: [
                        ...actions,
                        if (summary != null) _summary(context),
                        ?primaryAction,
                      ],
                    ),
                  ),
                  if (search != null)
                    SizedBox(width: searchWidth, child: search),
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
  }

  Widget _summary(BuildContext context) => DefaultTextStyle.merge(
    style: Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    child: summary!,
  );
}
