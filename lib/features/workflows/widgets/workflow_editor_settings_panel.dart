part of '../pages/workflow_editor_page.dart';

/// Ajustes de la orquestación, dentro del panel lateral del editor.
///
/// Vivían en una tarjeta encima del lienzo, y con sus ~318 px de alto fijo el
/// lienzo —que es la herramienta de la pantalla— se quedaba con lo que sobrara:
/// unos 328 px en una ventana de 820, y 136 si además había problemas que
/// mostrar. Como el `fitToView` del lienzo encoge los nodos hasta que quepan,
/// el resultado era un diagrama ilegible bajo un formulario enorme.
///
/// El nombre no baja aquí: se queda en la cabecera, siempre a la vista. Es un
/// campo obligatorio, y esconder su error de validación es exactamente lo que
/// hizo retirar el `ExpansionTile` que envolvía esta tarjeta.
extension _WorkflowEditorSettingsPanel on _WorkflowEditorPageState {
  /// El nombre, como título editable de la cabecera.
  ///
  /// Es el único campo obligatorio del formulario, así que se queda en el sitio
  /// más visible de la pantalla en lugar de bajar al panel con el resto.
  Widget _buildTituloEditable() {
    return TextFormField(
      controller: _nameController,
      maxLength: maxLabelLength,
      buildCounter:
          (_, {required currentLength, required isFocused, maxLength}) => null,
      style: Theme.of(context).textTheme.titleLarge,
      decoration: InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        hintText: _tx('workflow_editor.name_label'),
      ),
      validator: (value) => (value ?? '').trim().isEmpty
          ? _tx('workflow_editor.name_required')
          : null,
      onChanged: (_) => _refresh(() {}),
    );
  }

  Widget _buildSettingsPanel() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        WorkflowMetadataCard(
          mostrarNombre: false,
          conSuperficie: false,
          nameController: _nameController,
          descriptionController: _descriptionController,
          llmOrchestrations: _llmOrchestrations,
          llmOrchestrationConnectionId: _llmOrchestrationConnectionId,
          onLlmOrchestrationChanged: (value) =>
              _refresh(() => _llmOrchestrationConnectionId = value),
          isPublic: _labels.contains('public'),
          onChanged: () => _refresh(() {}),
          onVisibilityChanged: (isPublic) => _refresh(() {
            // Se conservan las etiquetas propias del usuario; solo cambia el
            // par private/public.
            _labels = [
              for (final label in _labels)
                if (label != 'private' && label != 'public') label,
              isPublic ? 'public' : 'private',
            ];
          }),
          selectedLanguageLabels: _labels.where(isLanguageLabel).toSet(),
          onLanguageLabelsChanged: (next) => _refresh(() {
            _labels = [
              for (final label in _labels)
                if (!isLanguageLabel(label)) label,
              ...next,
            ];
          }),
          tx: _tx,
        ),
      ],
    );
  }
}
