import 'package:flutter/material.dart';

import '../../../shared/widgets/lazy_expansion_tile.dart';
import '../models/official_import_models.dart';
import 'official_import_component_tile.dart';

/// Grupos de la revisión de importación, como sliver perezoso.
///
/// Un repositorio oficial trae cientos de componentes. Construirlos todos por
/// adelantado era doblemente caro: `ExpansionTile` construye sus hijos aunque
/// esté colapsado —solo los oculta—, así que la pantalla pagaba cada tile con
/// sus desplegables y checkboxes antes de pintar el primero, y ninguno de esos
/// hijos se veía. Aquí los grupos se construyen al entrar en pantalla y sus
/// componentes solo cuando el grupo se abre.
class OfficialImportGroupsSliver extends StatelessWidget {
  const OfficialImportGroupsSliver({
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
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text(tx('common.no_results', 'Sin resultados'))),
        ),
      );
    }
    final entries = groups.entries.toList(growable: false);
    return SliverList.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          child: LazyExpansionTile(
            // Sin key, reciclar el elemento al desplazarse le pasaría el estado
            // de apertura de un grupo a otro.
            key: ValueKey(entry.key),
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: Text('${entry.key} (${entry.value.length})'),
            childrenBuilder: () => [
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
        );
      },
    );
  }
}
