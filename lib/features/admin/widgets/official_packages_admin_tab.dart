import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../dialogs/official_package_dialogs.dart';
import '../repositories/admin_official_packages_repository.dart';

class OfficialPackagesAdminTab extends StatefulWidget {
  const OfficialPackagesAdminTab({
    required this.apiClient,
    required this.token,
    required this.tx,
    super.key,
  });

  final ApiClient apiClient;
  final String token;
  final String Function(String, String) tx;

  @override
  State<OfficialPackagesAdminTab> createState() =>
      _OfficialPackagesAdminTabState();
}

class _OfficialPackagesAdminTabState extends State<OfficialPackagesAdminTab> {
  late final repository = AdminOfficialPackagesRepository(
    apiClient: widget.apiClient,
  );
  List<Map<String, dynamic>> packages = const [];
  bool loading = true;
  String? error;
  final Set<String> busy = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await repository.list(widget.token);
      if (!mounted) return;
      setState(() {
        packages = result;
        loading = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.toString();
        loading = false;
      });
    }
  }

  Future<void> run(String key, Future<void> Function() action) async {
    setState(() => busy.add(key));
    try {
      await action();
      await load();
    } finally {
      if (mounted) setState(() => busy.remove(key));
    }
  }

  Future<void> openImport() async {
    final controller = TextEditingController();
    String mode = 'release';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            widget.tx('official.admin_import', 'Importar desde GitHub'),
          ),
          content: SizedBox(
            width: dialogContentWidth(context, 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'https://github.com/owner/repository',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: mode,
                  decoration: InputDecoration(
                    labelText: widget.tx('official.tracking', 'Seguimiento'),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'release',
                      child: Text('Última release'),
                    ),
                    DropdownMenuItem(value: 'branch', child: Text('Rama main')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => mode = value ?? mode),
                ),
              ],
            ),
          ),
          actions: [
            TertiaryButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.tx('common.cancel', 'Cancelar')),
            ),
            PrimaryButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.tx('common.import', 'Importar')),
            ),
          ],
        ),
      ),
    );
    final url = controller.text.trim();
    controller.dispose();
    if (accepted != true || url.isEmpty) return;
    await run(
      'import',
      () => repository.importRepository(widget.token, url, trackingMode: mode),
    );
  }

  Future<void> showDiff(Map<String, dynamic> package, String version) async {
    final value = await repository.diff(
      widget.token,
      package['id'].toString(),
      version,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(widget.tx('official.review_changes', 'Revisar cambios')),
        content: SizedBox(
          width: dialogContentWidth(context, 680),
          height: dialogContentHeight(context, 440),
          child: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(value),
            ),
          ),
        ),
        actions: [
          PrimaryButton(
            onPressed: () => Navigator.pop(context),
            child: Text(widget.tx('common.close', 'Cerrar')),
          ),
        ],
      ),
    );
  }

  Future<void> deletePackage(Map<String, dynamic> package) async {
    final id = package['id'].toString();
    final name = package['name']?.toString().trim().isNotEmpty == true
        ? package['name'].toString()
        : widget.tx('official.unnamed_package', 'Paquete sin nombre');
    final confirmed = await showConfirmActionDialog(
      context,
      title: widget.tx('official.delete_title', 'Eliminar fuente oficial'),
      message: widget
          .tx(
            'official.delete_confirm',
            'Se eliminarán {name}, sus versiones y revisiones. Dejará de aparecer en Explorar y se retirarán todos sus enlaces. Los forks privados se conservarán.',
          )
          .replaceAll('{name}', name),
      cancelLabel: widget.tx('common.cancel', 'Cancelar'),
      confirmLabel: widget.tx('common.delete', 'Eliminar'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await run(id, () => repository.deletePackage(widget.token, id));
  }

  Future<void> editPackage(Map<String, dynamic> package) async {
    final payload = await showOfficialPackageEditDialog(
      context,
      package: package,
      tx: widget.tx,
    );
    if (payload == null || !mounted) return;
    final id = package['id'].toString();
    await run(id, () => repository.updatePackage(widget.token, id, payload));
  }

  Future<void> syncPackage(Map<String, dynamic> package) async {
    final id = package['id'].toString();
    await run(id, () => repository.sync(widget.token, id));
  }

  Future<void> publishVersion(
    Map<String, dynamic> package,
    Map<String, dynamic> version,
  ) async {
    final selected = await showOfficialVersionPublishDialog(
      context,
      version: version,
      tx: widget.tx,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final packageId = package['id'].toString();
    final value = version['version'].toString();
    await run(
      '$packageId:$value',
      () => repository.review(
        widget.token,
        packageId,
        value,
        publish: true,
        componentIds: selected,
      ),
    );
  }

  Future<void> syncPackages() async {
    final selected = await showOfficialPackageSyncDialog(
      context,
      packages: packages,
      tx: widget.tx,
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    setState(() => busy.add('sync-selected'));
    final failed = <String>[];
    for (final id in selected) {
      try {
        await repository.sync(widget.token, id);
      } catch (_) {
        failed.add(id);
      }
    }
    await load();
    if (!mounted) return;
    setState(() => busy.remove('sync-selected'));
    final message = failed.isEmpty
        ? widget
              .tx('official.sync_completed', '{count} paquetes sincronizados')
              .replaceAll('{count}', '${selected.length}')
        : widget
              .tx(
                'official.sync_partial',
                '{synced} sincronizados, {failed} con error',
              )
              .replaceAll('{synced}', '${selected.length - failed.length}')
              .replaceAll('{failed}', '${failed.length}');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) return Center(child: Text(error!));
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PrimaryButton.icon(
                  onPressed: busy.contains('import') ? null : openImport,
                  icon: const Icon(Icons.add_link),
                  label: Text(
                    widget.tx(
                      'official.admin_add_source',
                      'Añadir fuente oficial',
                    ),
                  ),
                ),
                SecondaryButton.icon(
                  onPressed: packages.isEmpty || busy.contains('sync-selected')
                      ? null
                      : syncPackages,
                  icon: const Icon(Icons.sync),
                  label: Text(
                    widget.tx('official.sync_packages', 'Sincronizar'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (final package in packages) _packageCard(package),
          if (packages.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.tx(
                    'official.admin_empty',
                    'No hay fuentes configuradas.',
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _packageCard(Map<String, dynamic> package) {
    final id = package['id'].toString();
    final name = package['name']?.toString().trim() ?? '';
    final versions = (package['versions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name.isNotEmpty
                        ? name
                        : widget.tx(
                            'official.unnamed_package',
                            'Paquete sin nombre',
                          ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                ActionIconButton(
                  tooltip: widget.tx(
                    'official.sync_source',
                    'Sincronizar esta fuente',
                  ),
                  onPressed: busy.contains(id)
                      ? null
                      : () => syncPackage(package),
                  icon: Icons.sync,
                ),
                ActionIconButton(
                  tooltip: widget.tx('common.edit', 'Editar'),
                  onPressed: busy.contains(id)
                      ? null
                      : () => editPackage(package),
                  icon: Icons.edit_outlined,
                ),
                ActionIconButton(
                  tooltip: widget.tx(
                    'official.delete_source',
                    'Eliminar fuente',
                  ),
                  onPressed: busy.contains(id)
                      ? null
                      : () => deletePackage(package),
                  icon: Icons.delete_outline,
                  danger: true,
                ),
              ],
            ),
            Text(package['repository_url']?.toString() ?? ''),
            if ((package['last_sync_error']?.toString() ?? '').isNotEmpty)
              Text(
                package['last_sync_error'].toString(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Divider(),
            for (final version in versions) _versionRow(package, version),
          ],
        ),
      ),
    );
  }

  Widget _versionRow(
    Map<String, dynamic> package,
    Map<String, dynamic> version,
  ) {
    final packageId = package['id'].toString();
    final value = version['version'].toString();
    final status = version['status'].toString();
    final key = '$packageId:$value';
    final errors = version['validation_errors'] as List? ?? const [];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('$value · $status'),
      subtitle: errors.isEmpty ? null : Text(errors.join('\n')),
      trailing: Wrap(
        spacing: 4,
        children: [
          ActionIconButton(
            tooltip: widget.tx('official.review_changes', 'Revisar cambios'),
            onPressed: () => showDiff(package, value),
            icon: Icons.difference_outlined,
          ),
          if (status == 'pending_review') ...[
            ActionIconButton(
              tooltip: widget.tx('common.reject', 'Rechazar'),
              onPressed: busy.contains(key)
                  ? null
                  : () => run(
                      key,
                      () => repository.review(
                        widget.token,
                        packageId,
                        value,
                        publish: false,
                      ),
                    ),
              icon: Icons.close,
              danger: true,
            ),
            ActionIconButton(
              tooltip: widget.tx('common.publish', 'Publicar'),
              onPressed: busy.contains(key)
                  ? null
                  : () => publishVersion(package, version),
              icon: Icons.publish,
            ),
          ],
        ],
      ),
    );
  }
}
