import 'package:flutter/material.dart';

import '../models/official_import_models.dart';
import 'official_import_component_tile.dart';

class OfficialImportGroups extends StatelessWidget {
  const OfficialImportGroups({
    required this.groups,
    required this.busy,
    required this.tx,
    required this.onToggle,
    required this.onClassify,
    required this.onLanguage,
    required this.onToolLanguage,
    required this.onEditRelations,
    required this.onReviewTool,
    super.key,
  });

  final Map<String, List<ImportComponent>> groups;
  final bool busy;
  final String Function(String, String) tx;
  final void Function(ImportComponent, bool) onToggle;
  final void Function(ImportComponent, String?) onClassify;
  final void Function(ImportComponent, String?) onLanguage;
  final void Function(ImportComponent, String?) onToolLanguage;
  final ValueChanged<ImportComponent> onEditRelations;
  final ValueChanged<ImportComponent> onReviewTool;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final entry in groups.entries)
        Card(
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text('${entry.key} (${entry.value.length})'),
            children: [
              for (final component in entry.value)
                OfficialImportComponentTile(
                  component: component,
                  busy: busy,
                  tx: tx,
                  onToggle: (value) => onToggle(component, value),
                  onClassify: (value) => onClassify(component, value),
                  onLanguage: (value) => onLanguage(component, value),
                  onToolLanguage: (value) => onToolLanguage(component, value),
                  onEditRelations: () => onEditRelations(component),
                  onReviewTool: () => onReviewTool(component),
                ),
            ],
          ),
        ),
      if (groups.isEmpty)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(tx('common.no_results', 'Sin resultados'))),
        ),
    ],
  );
}
