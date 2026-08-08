import 'package:flutter/material.dart';

import '../../../app/theme/fnc_colors.dart';
import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';

typedef LabelText = String Function(String path, String fallback);

const _blockingLabels = {'draft', 'quarantine', 'archived', 'delete'};

/// Cabecera del catálogo: título + intro, como card independiente encima
/// de la rejilla de grupos.
class LabelCatalogIntro extends StatelessWidget {
  const LabelCatalogIntro({required this.text, super.key});

  final LabelText text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text('labels.catalog_title', 'Catálogo de etiquetas'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: FncFonts.size16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text(
                'labels.catalog_intro',
                'Las etiquetas definen el estado y comportamiento de tus recursos. '
                    'Cada recurso tiene siempre al menos una etiqueta de visibilidad.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de un grupo (Propiedad, Visibilidad, Entorno, Estado) con sus
/// entradas individuales, pensada para fluir en una rejilla responsive.
class LabelGroupCard extends StatefulWidget {
  const LabelGroupCard({required this.group, required this.text, super.key});

  final LabelGroupDef group;
  final LabelText text;

  @override
  State<LabelGroupCard> createState() => _LabelGroupCardState();
}

class _LabelGroupCardState extends State<LabelGroupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final text = widget.text;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    text(group.titleKey, group.fallbackTitle),
                    style: const TextStyle(
                      fontSize: FncFonts.size15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AppIconButton(
                  key: ValueKey('label-group-toggle-${group.titleKey}'),
                  onPressed: () => setState(() => _expanded = !_expanded),
                  tooltip: _expanded
                      ? text('labels.collapse_group', 'Ocultar descripciones')
                      : text('labels.expand_group', 'Mostrar descripciones'),
                  icon: AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ),
              ],
            ),
            Text(
              group.exclusive
                  ? text(
                      'labels.exclusive_hint',
                      'Exclusivas (solo una activa)',
                    )
                  : text('labels.multi_hint', 'Multi-selección'),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              child: _expanded
                  ? Column(
                      children: [
                        const SizedBox(height: 10),
                        for (final key in group.keys)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _LabelEntryCard(labelKey: key, text: text),
                          ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelEntryCard extends StatelessWidget {
  const _LabelEntryCard({required this.labelKey, required this.text});

  final String labelKey;
  final LabelText text;

  @override
  Widget build(BuildContext context) {
    final showsBehavior =
        _blockingLabels.contains(labelKey) || labelKey == 'deprecated';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
      color = FncColors.materialRed.shade700;
    } else {
      label = text('labels.behavior_warns', 'Aviso visual');
      color = FncColors.materialAmber.shade800;
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
          fontSize: FncFonts.size11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
