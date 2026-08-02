import 'package:flutter/material.dart';

import '../models/workflow_graph_validation.dart';

/// Nombre, descripción y visibilidad de la orquestación.
///
/// Antes vivía dentro de un `ExpansionTile` que arrancaba colapsado al editar:
/// el nombre es obligatorio, así que su error de validación quedaba escondido.
class WorkflowMetadataCard extends StatelessWidget {
  const WorkflowMetadataCard({
    required this.nameController,
    required this.descriptionController,
    required this.isPublic,
    required this.onVisibilityChanged,
    required this.onChanged,
    required this.tx,
    super.key,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final bool isPublic;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onChanged;
  final String Function(String path, String fallback) tx;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final name = TextFormField(
            controller: nameController,
            maxLength: maxLabelLength,
            buildCounter:
                (_, {required currentLength, required isFocused, maxLength}) =>
                    null,
            decoration: InputDecoration(
              labelText: tx('workflow_editor.name_label', 'Nombre'),
              prefixIcon: const Icon(Icons.badge_outlined, size: 19),
            ),
            onChanged: (_) => onChanged(),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? tx('workflow_editor.name_required', 'Nombre obligatorio')
                : null,
          );
          final description = TextFormField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: tx('workflow_editor.description_label', 'Descripción'),
              prefixIcon: const Icon(Icons.notes_rounded, size: 19),
            ),
            onChanged: (_) => onChanged(),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (constraints.maxWidth >= 720)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: name),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: description),
                  ],
                )
              else ...[
                name,
                const SizedBox(height: 12),
                description,
              ],
              const SizedBox(height: 12),
              _visibility(context),
            ],
          );
        },
      ),
    );
  }

  Widget _visibility(BuildContext context) {
    return Row(
      children: [
        Text(
          tx('workflow_editor.labels_label', 'Visibilidad'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 12),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              icon: const Icon(Icons.lock_outline, size: 16),
              label: Text(tx('workflow_editor.visibility_private', 'Privada')),
            ),
            ButtonSegment(
              value: true,
              icon: const Icon(Icons.public, size: 16),
              label: Text(tx('workflow_editor.visibility_public', 'Pública')),
            ),
          ],
          selected: {isPublic},
          onSelectionChanged: (selection) =>
              onVisibilityChanged(selection.first),
        ),
      ],
    );
  }
}
