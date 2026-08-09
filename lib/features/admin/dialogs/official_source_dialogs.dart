import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../../../shared/widgets/responsive_dialog.dart';

typedef AdminTx = String Function(String path, String fallback);

/// Mismos textos que el filtro de tipo de Explorar, para que un componente se
/// llame igual en todo el producto.
String _componentTypeLabel(AdminTx tx, String type) {
  return switch (type) {
    'agent' => tx('explore.type_agents', 'Agentes'),
    'skill' => tx('explore.type_skills', 'Skills'),
    'prompt' => tx('explore.type_prompts', 'Prompts'),
    'tool' => tx('explore.type_tools', 'Herramientas'),
    'knowledge' => tx('explore.type_knowledge', 'Knowledge'),
    'workflow' => tx('explore.type_workflows', 'Workflows'),
    _ => type,
  };
}

Future<Map<String, dynamic>?> showOfficialSourceEditDialog(
  BuildContext context, {
  required Map<String, dynamic> source,
  required AdminTx tx,
}) async {
  final name = TextEditingController(text: source['name']?.toString() ?? '');
  final description = TextEditingController(
    text: source['description']?.toString() ?? '',
  );
  final repositoryUrl = TextEditingController(
    text: source['repository_url']?.toString() ?? '',
  );
  final trackingRef = TextEditingController(
    text: source['tracking_ref']?.toString() ?? 'main',
  );
  final license = TextEditingController(
    text: source['license']?.toString() ?? '',
  );
  var trackingMode = source['tracking_mode']?.toString() == 'branch'
      ? 'branch'
      : 'release';
  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(tx('official.edit_title', 'Editar fuente oficial')),
        content: SizedBox(
          width: dialogContentWidth(context, 580),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: InputDecoration(
                    labelText: tx('official.name', 'Nombre'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: tx('common.description', 'Descripción'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: repositoryUrl,
                  decoration: InputDecoration(
                    labelText: tx(
                      'official.repository_url',
                      'Repositorio de GitHub',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: trackingMode,
                  decoration: InputDecoration(
                    labelText: tx('official.tracking', 'Seguimiento'),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'release',
                      child: Text(
                        tx('official.tracking_release', 'Última release'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'branch',
                      child: Text(tx('official.tracking_branch', 'Rama')),
                    ),
                  ],
                  onChanged: (value) => setDialogState(
                    () => trackingMode = value ?? trackingMode,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: trackingRef,
                  decoration: InputDecoration(
                    labelText: tx('official.tracking_ref', 'Referencia'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: license,
                  decoration: InputDecoration(
                    labelText: tx('official.license', 'Licencia'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            onPressed: () {
              if (name.text.trim().isEmpty ||
                  repositoryUrl.text.trim().isEmpty ||
                  trackingRef.text.trim().isEmpty) {
                return;
              }
              Navigator.pop(context, {
                'name': name.text.trim(),
                'description': description.text.trim(),
                'repository_url': repositoryUrl.text.trim(),
                'tracking_mode': trackingMode,
                'tracking_ref': trackingRef.text.trim(),
                'license': license.text.trim(),
              });
            },
            child: Text(tx('common.save', 'Guardar')),
          ),
        ],
      ),
    ),
  );
  // showDialog completa al iniciar el pop; el overlay todavía usa los
  // controladores durante su animación de salida.
  unawaited(
    Future<void>.delayed(kThemeAnimationDuration, () {
      name.dispose();
      description.dispose();
      repositoryUrl.dispose();
      trackingRef.dispose();
      license.dispose();
    }),
  );
  return result;
}

/// Selector del contenido que la fuente deja en el hub.
///
/// Arranca marcando lo que ya está (``alreadySelected``); en una fuente nueva,
/// todo. Desmarcar una fila y confirmar borra ese objeto del hub.
Future<Set<String>?> showOfficialComponentsDialog(
  BuildContext context, {
  required List<dynamic> components,
  required Set<String> alreadySelected,
  required List<String> errors,
  required AdminTx tx,
}) {
  final rows =
      components
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList()
        ..sort((a, b) {
          final type = (a['component_type']?.toString() ?? '').compareTo(
            b['component_type']?.toString() ?? '',
          );
          return type != 0
              ? type
              : (a['name']?.toString() ?? '').compareTo(
                  b['name']?.toString() ?? '',
                );
        });
  bool supported(Map<String, dynamic> component) =>
      component['materializable'] != false;
  final selected = rows
      .where(supported)
      .map((item) => item['component_id'].toString())
      .where((id) => alreadySelected.isEmpty || alreadySelected.contains(id))
      .toSet();
  final unsupported = rows.where((item) => !supported(item)).length;
  final byId = {
    for (final component in rows) component['component_id'].toString(): component,
  };

  bool dependsOn(String candidateId, String dependencyId, Set<String> seen) {
    if (!seen.add(candidateId)) return false;
    final candidate = byId[candidateId];
    for (final dependency
        in (candidate?['dependencies'] as List? ?? const [])) {
      final id = dependency.toString();
      if (id == dependencyId || dependsOn(id, dependencyId, seen)) return true;
    }
    return false;
  }

  return showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          tx('official.choose_publish_content', 'Elegir contenido de la fuente'),
        ),
        content: SizedBox(
          width: dialogContentWidth(context, 620),
          height: dialogContentHeight(context, 500),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tx(
                    'official.publish_selection_hint',
                    'Lo marcado queda publicado en el hub como un recurso más. '
                        'Lo que desmarques se borra.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (unsupported > 0) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tx(
                      'official.unsupported_hint',
                      '{count} objetos del repositorio no tienen equivalente en el hub '
                          '(hooks, MCP, reglas): salen en gris y no se pueden traer.',
                    ).replaceAll('{count}', '$unsupported'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
              if (errors.isNotEmpty) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    errors.join('\n'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final component in rows)
                      CheckboxListTile(
                        value: selected.contains(
                          component['component_id'].toString(),
                        ),
                        enabled: supported(component),
                        isThreeLine: true,
                        title: Text(component['name']?.toString() ?? ''),
                        // Dos componentes pueden llamarse igual (un SKILL.md
                        // por carpeta): la ruta en el repositorio es lo único
                        // que los distingue sin enseñar ids internos.
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              component['source_path']?.toString() ?? '',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontFamily: FncFonts.monospace),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Builder(
                                builder: (context) {
                                  final type =
                                      component['component_type']?.toString() ??
                                      '';
                                  return ResourceTypeBadge(
                                    type: type,
                                    label: _componentTypeLabel(tx, type),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        onChanged: (checked) => setDialogState(() {
                          final id = component['component_id'].toString();
                          if (checked == true) {
                            selected.add(id);
                            for (final dependency
                                in (component['dependencies'] as List? ??
                                    const [])) {
                              selected.add(dependency.toString());
                            }
                          } else {
                            selected.removeWhere(
                              (candidate) =>
                                  candidate == id ||
                                  dependsOn(candidate, id, <String>{}),
                            );
                          }
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            // Vaciar la selección es una acción válida: deja la fuente dada de
            // alta pero sin nada suyo publicado en el hub.
            onPressed: () => Navigator.pop(context, Set.of(selected)),
            child: Text(tx('official.publish_selection', 'Aplicar selección')),
          ),
        ],
      ),
    ),
  );
}
