import 'package:flutter/material.dart';

/// Composición uniforme para búsquedas, acciones y resumen de colecciones.
class ResourceToolbar extends StatelessWidget {
  const ResourceToolbar({
    required this.actions,
    this.search,
    this.summary,
    this.actionSpacing = 6,
    this.sectionSpacing = 12,
    super.key,
  });

  final Widget? search;
  final List<Widget> actions;
  final Widget? summary;
  final double actionSpacing;
  final double sectionSpacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (search != null) ...[search!, SizedBox(height: sectionSpacing)],
        Wrap(
          spacing: actionSpacing,
          runSpacing: actionSpacing,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: actions,
        ),
        if (summary != null) ...[SizedBox(height: sectionSpacing), summary!],
      ],
    );
  }
}
