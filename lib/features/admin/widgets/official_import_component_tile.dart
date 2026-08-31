import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../core/config/content_languages.dart';
import '../../../core/config/tool_runtimes.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../../../utils/i18n.dart';
import '../models/official_import_models.dart';

class OfficialImportComponentTile extends StatelessWidget {
  const OfficialImportComponentTile({
    required this.component,
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

  final ImportComponent component;
  final bool busy;
  final String Function(String) tx;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String?> onClassify;
  final ValueChanged<String?> onLanguage;
  final ValueChanged<String?> onToolLanguage;
  final VoidCallback onEditRelations;
  final VoidCallback onReviewTool;

  @override
  Widget build(BuildContext context) {
    final needsClassification = !component.materializable;
    final canSelect = component.materializable || component.forcedType != null;
    final enabled = !busy && !component.securityBlocked && canSelect;
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 600;
        final title = Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(component.name),
            ResourceTypeBadge(
              type: component.effectiveType,
              label: component.effectiveType,
            ),
            Chip(label: Text(component.state)),
            if (component.omitted) Chip(label: Text(tx('official.omitted'))),
          ],
        );
        final details = _details(
          context,
          needsClassification: needsClassification,
          fieldWidth: mobile ? constraints.maxWidth : 220,
        );
        if (!mobile) {
          return CheckboxListTile(
            key: ValueKey(component.id),
            value: component.selected,
            enabled: enabled,
            onChanged: canSelect ? (value) => onToggle(value == true) : null,
            title: title,
            subtitle: details,
          );
        }
        return Padding(
          key: ValueKey(component.id),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    label: component.name,
                    checked: component.selected,
                    child: Checkbox(
                      value: component.selected,
                      onChanged: enabled
                          ? (value) => onToggle(value == true)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(child: title),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: details,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _details(
    BuildContext context, {
    required bool needsClassification,
    required double fieldWidth,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        component.sourcePath,
        style: const TextStyle(fontFamily: FncFonts.monospace),
      ),
      if (component.variants.isNotEmpty)
        Text(
          tx('official.variants_grouped')
              .replaceAll('{count}', '${component.variants.length}'),
        ),
      if (component.dependencies.isNotEmpty)
        Text('${tr('admin.depends_on')}: ${component.dependencies.join(', ')}'),
      for (final relation in component.relations)
        Text('${relation.type}: ${relation.targetId}'),
      if (component.omitted) Text(tx('official.omitted_explanation')),
      if (component.effectiveType == 'agent')
        Align(
          alignment: Alignment.centerLeft,
          child: TertiaryButton.icon(
            onPressed: busy ? null : onEditRelations,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text(tx('official.edit_relations')),
          ),
        ),
      if (needsClassification)
        SizedBox(
          width: fieldWidth,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: component.forcedType,
            decoration: InputDecoration(labelText: tx('official.classify_as')),
            items: [
              DropdownMenuItem(
                value: 'agent',
                child: Text(tx('official.type_agent')),
              ),
              DropdownMenuItem(
                value: 'skill',
                child: Text(tx('official.type_skill')),
              ),
              DropdownMenuItem(
                value: 'prompt',
                child: Text(tx('official.type_prompt')),
              ),
              DropdownMenuItem(
                value: 'knowledge',
                child: Text(tx('official.type_knowledge')),
              ),
              DropdownMenuItem(
                value: 'tool',
                child: Text(tx('official.type_tool')),
              ),
              DropdownMenuItem(
                value: 'memory',
                child: Text(tx('official.type_memory')),
              ),
              DropdownMenuItem(
                value: 'workflow',
                child: Text(tx('official.type_workflow')),
              ),
            ],
            onChanged: busy ? null : onClassify,
          ),
        ),
      SizedBox(
        width: fieldWidth,
        child: DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: component.language.isEmpty ? '' : component.language,
          decoration: InputDecoration(labelText: tx('official.language')),
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(tx('official.unspecified')),
            ),
            for (final language in ContentLanguages.values)
              DropdownMenuItem(
                value: language.labelKey,
                child: Text(tx('labels.${language.labelKey}')),
              ),
          ],
          onChanged: busy ? null : onLanguage,
        ),
      ),
      if (component.effectiveType == 'tool')
        SizedBox(
          width: fieldWidth,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: component.toolLanguage?.apiValue ?? '',
            decoration: InputDecoration(
              labelText: tx('official.tool_language'),
            ),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(tx('official.unspecified')),
              ),
              for (final language in ToolRuntimeCatalog.supported)
                DropdownMenuItem(
                  value: language.apiValue,
                  child: Text(language.label(tx)),
                ),
            ],
            onChanged: busy ? null : onToolLanguage,
          ),
        ),
      if (component.securityReviewRequired || component.effectiveType == 'tool')
        Align(
          alignment: Alignment.centerLeft,
          child: TertiaryButton.icon(
            onPressed: busy ? null : onReviewTool,
            icon: Icon(
              component.securityAccepted ? Icons.verified_outlined : Icons.code,
            ),
            label: Text(
              component.securityAccepted
                  ? tx('official.reviewed')
                  : tx('official.review_code'),
            ),
          ),
        ),
    ],
  );
}
