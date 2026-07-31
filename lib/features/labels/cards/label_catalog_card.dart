import 'package:flutter/material.dart';

import '../../../shared/labels/label_catalog.dart';

typedef LabelText = String Function(String path, String fallback);

const _blockingLabels = {'draft', 'quarantine', 'archived', 'delete'};

class LabelCatalogCard extends StatelessWidget {
  const LabelCatalogCard({
    required this.text,
    this.initiallyExpanded = false,
    super.key,
  });

  final LabelText text;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          title: Text(
            text('labels.catalog_title', 'Catálogo de etiquetas'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text(
              text(
                'labels.catalog_intro',
                'Las etiquetas definen el estado y comportamiento de tus recursos. '
                    'Cada recurso tiene siempre al menos una etiqueta de visibilidad.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            for (final group in [kOwnershipGroup, ...kLabelGroups]) ...[
              Text(
                text(group.titleKey, group.fallbackTitle),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                group.exclusive
                    ? text(
                        'labels.exclusive_hint',
                        'Exclusivas (solo una activa)',
                      )
                    : text('labels.multi_hint', 'Multi-selección'),
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              for (final key in group.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LabelCatalogEntry(labelKey: key, text: text),
                ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}

class _LabelCatalogEntry extends StatelessWidget {
  const _LabelCatalogEntry({required this.labelKey, required this.text});

  final String labelKey;
  final LabelText text;

  @override
  Widget build(BuildContext context) {
    final showsBehavior =
        _blockingLabels.contains(labelKey) ||
        labelKey == 'deprecated' ||
        labelKey == 'private';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: CircleAvatar(
              radius: 5,
              backgroundColor: labelColor(labelKey),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text('labels.$labelKey', labelKey),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  text('labels.desc_$labelKey', ''),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (showsBehavior) ...[
                  const SizedBox(height: 6),
                  _LabelBehaviorChip(labelKey: labelKey, text: text),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelBehaviorChip extends StatelessWidget {
  const _LabelBehaviorChip({required this.labelKey, required this.text});

  final String labelKey;
  final LabelText text;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    if (_blockingLabels.contains(labelKey)) {
      label = text('labels.behavior_blocks', 'Bloquea el recurso');
      color = Colors.red.shade700;
    } else if (labelKey == 'deprecated') {
      label = text('labels.behavior_warns', 'Aviso visual');
      color = Colors.amber.shade800;
    } else {
      label = text('labels.behavior_default', 'Por defecto');
      color = Theme.of(context).colorScheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
