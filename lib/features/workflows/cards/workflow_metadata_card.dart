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
    this.mostrarNombre = true,
    this.conSuperficie = true,
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
  final String Function(String path) tx;

  /// Si el nombre lo pinta otro (la cabecera del editor), aquí sobra.
  ///
  /// El campo no se esconde: **se muda**. Ver la nota de arriba sobre el
  /// `ExpansionTile` — lo que no puede pasar es que el error de validación de
  /// un campo obligatorio quede fuera de la vista.
  final bool mostrarNombre;

  /// Dentro de un panel que ya tiene fondo y borde, el suyo sobra: dos cajas
  /// anidadas con el mismo trazo se leen como un error de maquetación.
  final bool conSuperficie;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: conSuperficie
          ? const EdgeInsets.fromLTRB(16, 14, 16, 16)
          : EdgeInsets.zero,
      decoration: conSuperficie
          ? BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            )
          : null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final name = TextFormField(
            controller: nameController,
            maxLength: maxLabelLength,
            buildCounter: (
              _, {
              required currentLength,
              required isFocused,
              maxLength,
            }) => null,
            decoration: InputDecoration(
              labelText: tx('workflow_editor.name_label'),
              prefixIcon: const Icon(Icons.badge_outlined, size: 19),
            ),
            onChanged: (_) => onChanged(),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? tx('workflow_editor.name_required')
                : null,
          );
          final description = TextFormField(
            controller: descriptionController,
            decoration: InputDecoration(
              labelText: tx('workflow_editor.description_label'),
              prefixIcon: const Icon(Icons.notes_rounded, size: 19),
            ),
            onChanged: (_) => onChanged(),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mostrarNombre)
                description
              else if (constraints.maxWidth >= 720)
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
                  labelText: tx('workflow_editor.llm_orchestration_label'),
                  helperText: tx('workflow_editor.llm_orchestration_help'),
                  prefixIcon: const Icon(Icons.hub_outlined, size: 19),
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(
                      tx('workflow_editor.llm_orchestration_agent_default'),
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
      tx('workflow_editor.labels_label'),
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontWeight: FontWeight.w700),
    );
    final selector = SegmentedButton<bool>(
      expandedInsets: EdgeInsets.zero,
      segments: [
        ButtonSegment(
          value: false,
          icon: const Icon(Icons.lock_outline, size: 16),
          label: Text(tx('workflow_editor.visibility_private')),
        ),
        ButtonSegment(
          value: true,
          icon: const Icon(Icons.public, size: 16),
          label: Text(tx('workflow_editor.visibility_public')),
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
        // `selector` lleva `expandedInsets: EdgeInsets.zero`, así que quiere
        // todo el ancho que le den. Suelto en un `Row` lo que le llega es
        // ancho **no acotado**, y el SegmentedButton lanza «BoxConstraints
        // forces an infinite width»: la excepción aborta la maquetación y el
        // editor entero se queda sin pintar —cabecera y negro—. En la rama
        // estrecha no pasaba porque la `Column` con `stretch` sí lo acota, y
        // por eso la prueba de 360 px lo daba por bueno.
        return Row(
          children: [
            label,
            const SizedBox(width: 12),
            Expanded(child: selector),
          ],
        );
      },
    );
  }
}
