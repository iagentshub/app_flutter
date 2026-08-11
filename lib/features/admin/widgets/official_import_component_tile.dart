import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../models/official_import_models.dart';

class OfficialImportComponentTile extends StatelessWidget {
  const OfficialImportComponentTile({
    required this.component,
    required this.busy,
    required this.tx,
    required this.onToggle,
    required this.onClassify,
    required this.onLanguage,
    required this.onEditRelations,
    required this.onReviewTool,
    super.key,
  });

  final ImportComponent component;
  final bool busy;
  final String Function(String, String) tx;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String?> onClassify;
  final ValueChanged<String?> onLanguage;
  final VoidCallback onEditRelations;
  final VoidCallback onReviewTool;

  @override
  Widget build(BuildContext context) {
    final needsClassification = !component.materializable;
    return CheckboxListTile(
      key: ValueKey(component.id),
      value: component.selected,
      enabled: !busy && !component.securityBlocked,
      onChanged: (value) => onToggle(value == true),
      title: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(component.name),
          ResourceTypeBadge(
            type: component.effectiveType,
            label: component.effectiveType,
          ),
          Chip(label: Text(component.state)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            component.sourcePath,
            style: const TextStyle(fontFamily: FncFonts.monospace),
          ),
          if (component.variants.isNotEmpty)
            Text('${component.variants.length} variantes agrupadas'),
          if (component.dependencies.isNotEmpty)
            Text('Depende de: ${component.dependencies.join(', ')}'),
          if (component.effectiveType == 'agent')
            Align(
              alignment: Alignment.centerLeft,
              child: TertiaryButton.icon(
                onPressed: busy ? null : onEditRelations,
                icon: const Icon(Icons.account_tree_outlined),
                label: Text(tx('official.edit_relations', 'Editar relaciones')),
              ),
            ),
          if (needsClassification)
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: component.forcedType,
                decoration: InputDecoration(
                  labelText: tx('official.classify_as', 'Clasificar como'),
                ),
                items: const [
                  DropdownMenuItem(value: 'skill', child: Text('skill')),
                  DropdownMenuItem(value: 'prompt', child: Text('prompt')),
                  DropdownMenuItem(
                    value: 'knowledge',
                    child: Text('knowledge'),
                  ),
                  DropdownMenuItem(value: 'tool', child: Text('tool')),
                ],
                onChanged: busy ? null : onClassify,
              ),
            ),
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: component.language.isEmpty
                  ? ''
                  : component.language,
              decoration: InputDecoration(
                labelText: tx('official.language', 'Idioma'),
              ),
              items: const [
                DropdownMenuItem(value: '', child: Text('Sin especificar')),
                DropdownMenuItem(value: 'lang_es', child: Text('Español')),
                DropdownMenuItem(value: 'lang_en', child: Text('English')),
                DropdownMenuItem(value: 'lang_fr', child: Text('Français')),
                DropdownMenuItem(value: 'lang_de', child: Text('Deutsch')),
                DropdownMenuItem(value: 'lang_it', child: Text('Italiano')),
                DropdownMenuItem(value: 'lang_pt', child: Text('Português')),
              ],
              onChanged: busy ? null : onLanguage,
            ),
          ),
          if (component.securityReviewRequired ||
              component.effectiveType == 'tool')
            Align(
              alignment: Alignment.centerLeft,
              child: TertiaryButton.icon(
                onPressed: busy ? null : onReviewTool,
                icon: Icon(
                  component.securityAccepted
                      ? Icons.verified_outlined
                      : Icons.code,
                ),
                label: Text(
                  component.securityAccepted
                      ? tx('official.reviewed', 'Código revisado')
                      : tx('official.review_code', 'Revisar código'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
