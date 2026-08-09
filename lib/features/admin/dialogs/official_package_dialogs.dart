import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/responsive_dialog.dart';

typedef AdminTx = String Function(String path, String fallback);

Future<Map<String, dynamic>?> showOfficialPackageEditDialog(
  BuildContext context, {
  required Map<String, dynamic> package,
  required AdminTx tx,
}) async {
  final name = TextEditingController(text: package['name']?.toString() ?? '');
  final description = TextEditingController(
    text: package['description']?.toString() ?? '',
  );
  final repositoryUrl = TextEditingController(
    text: package['repository_url']?.toString() ?? '',
  );
  final trackingRef = TextEditingController(
    text: package['tracking_ref']?.toString() ?? 'main',
  );
  final license = TextEditingController(
    text: package['license']?.toString() ?? '',
  );
  var trackingMode = package['tracking_mode']?.toString() == 'branch'
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

Future<Set<String>?> showOfficialPackageSyncDialog(
  BuildContext context, {
  required List<Map<String, dynamic>> packages,
  required AdminTx tx,
}) {
  final selected = packages.map((item) => item['id'].toString()).toSet();
  return showDialog<Set<String>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(
          tx('official.sync_choose_title', 'Elegir paquetes para sincronizar'),
        ),
        content: SizedBox(
          width: dialogContentWidth(context, 540),
          height: dialogContentHeight(context, 420),
          child: Column(
            children: [
              Wrap(
                spacing: 8,
                children: [
                  TertiaryButton(
                    onPressed: () => setDialogState(() {
                      selected
                        ..clear()
                        ..addAll(packages.map((item) => item['id'].toString()));
                    }),
                    child: Text(
                      tx('official.sync_select_all', 'Seleccionar todo'),
                    ),
                  ),
                  TertiaryButton(
                    onPressed: () => setDialogState(selected.clear),
                    child: Text(tx('official.sync_clear', 'Limpiar')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final package in packages)
                      CheckboxListTile(
                        value: selected.contains(package['id'].toString()),
                        title: Text(
                          package['name']?.toString().trim().isNotEmpty == true
                              ? package['name'].toString()
                              : tx(
                                  'official.unnamed_package',
                                  'Paquete sin nombre',
                                ),
                        ),
                        subtitle: Text(
                          package['repository_url']?.toString() ?? '',
                        ),
                        onChanged: (checked) => setDialogState(() {
                          final id = package['id'].toString();
                          if (checked == true) {
                            selected.add(id);
                          } else {
                            selected.remove(id);
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
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, Set.of(selected)),
            child: Text(
              tx('official.sync_selected', 'Sincronizar seleccionados'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<Set<String>?> showOfficialVersionPublishDialog(
  BuildContext context, {
  required Map<String, dynamic> version,
  required AdminTx tx,
}) {
  final components =
      (version['components'] as List? ?? const [])
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
  final selected = components
      .map((item) => item['component_id'].toString())
      .toSet();
  final byId = {
    for (final component in components)
      component['component_id'].toString(): component,
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
          tx('official.choose_publish_content', 'Elegir contenido a publicar'),
        ),
        content: SizedBox(
          width: dialogContentWidth(context, 620),
          height: dialogContentHeight(context, 500),
          child: ListView(
            children: [
              for (final component in components)
                CheckboxListTile(
                  value: selected.contains(
                    component['component_id'].toString(),
                  ),
                  title: Text(component['name']?.toString() ?? ''),
                  subtitle: Text(component['component_type']?.toString() ?? ''),
                  onChanged: (checked) => setDialogState(() {
                    final id = component['component_id'].toString();
                    if (checked == true) {
                      selected.add(id);
                      for (final dependency
                          in (component['dependencies'] as List? ?? const [])) {
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
        actions: [
          TertiaryButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('common.cancel', 'Cancelar')),
          ),
          PrimaryButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, Set.of(selected)),
            child: Text(tx('official.publish_selection', 'Publicar selección')),
          ),
        ],
      ),
    ),
  );
}
