import 'package:flutter/material.dart';

import '../../../models/connections/connection_models.dart';
import '../../../shared/labels/label_catalog.dart';
import '../../../shared/widgets/grouped_label_picker.dart';
import '../models/workflow_graph_validation.dart';

/// Nombre, descripción y visibilidad de la orquestación.
///
/// Antes vivía dentro de un `ExpansionTile` que arrancaba colapsado al editar:
/// el nombre es obligatorio, así que su error de validación quedaba escondido.
class WorkflowMetadataCard extends StatelessWidget {
  const WorkflowMetadataCard({
    required this.nameController,
    required this.descriptionController,
    required this.llmOrchestrations,
    required this.llmOrchestrationConnectionId,
    required this.onLlmOrchestrationChanged,
    required this.isPublic,
    required this.onVisibilityChanged,
    required this.onChanged,
    required this.selectedLanguageLabels,
    required this.onLanguageLabelsChanged,
    required this.tx,
    super.key,
  });

  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final List<ConnectionItem> llmOrchestrations;
  final String? llmOrchestrationConnectionId;
  final ValueChanged<String?> onLlmOrchestrationChanged;
  final bool isPublic;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onChanged;
  final Set<String> selectedLanguageLabels;
  final ValueChanged<Set<String>> onLanguageLabelsChanged;
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
              DropdownButtonFormField<String?>(
                initialValue: llmOrchestrationConnectionId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tx(
                    'workflow_editor.llm_orchestration_label',
                    'Orquestación LLM predeterminada',
                  ),
                  helperText: tx(
                    'workflow_editor.llm_orchestration_help',
                    'Opcional. Sustituye la conexión de todos los agentes de este workflow.',
                  ),
                  prefixIcon: const Icon(Icons.hub_outlined, size: 19),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      tx(
                        'workflow_editor.llm_orchestration_agent_default',
                        'Usar la conexión de cada agente',
                      ),
                    ),
                  ),
                  ...llmOrchestrations.map(
                    (item) => DropdownMenuItem<String?>(
                      value: item.id,
                      child: Text(item.name),
                    ),
                  ),
                ],
                onChanged: onLlmOrchestrationChanged,
              ),
              const SizedBox(height: 12),
              _visibility(context),
              const SizedBox(height: 12),
              GroupedLabelPicker(
                selected: selectedLanguageLabels,
                onChanged: onLanguageLabelsChanged,
                tx: tx,
                groups: const [kLanguageLabelGroup],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _visibility(BuildContext context) {
    final label = Text(
      tx('workflow_editor.labels_label', 'Visibilidad'),
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
    );
    final selector = SegmentedButton<bool>(
      expandedInsets: EdgeInsets.zero,
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
      onSelectionChanged: (selection) => onVisibilityChanged(selection.first),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [label, const SizedBox(height: 8), selector],
          );
        }
        return Row(children: [label, const SizedBox(width: 12), selector]);
      },
    );
  }
}
