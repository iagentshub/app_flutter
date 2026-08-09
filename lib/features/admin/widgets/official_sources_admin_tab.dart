import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../dialogs/official_source_dialogs.dart';
import '../repositories/admin_official_sources_repository.dart';

/// Fuentes oficiales: repositorios de GitHub cuyo contenido se trae al hub
/// como recursos normales. Sincronizar es elegir qué se queda; lo que se
/// desmarca se borra igual que cualquier recurso.
class OfficialSourcesAdminTab extends StatefulWidget {
  const OfficialSourcesAdminTab({
    required this.apiClient,
    required this.token,
    required this.tx,
    super.key,
  });

  final ApiClient apiClient;
  final String token;
  final String Function(String, String) tx;

  @override
  State<OfficialSourcesAdminTab> createState() =>
      _OfficialSourcesAdminTabState();
}

class _OfficialSourcesAdminTabState extends State<OfficialSourcesAdminTab> {
  late final repository = AdminOfficialSourcesRepository(
    apiClient: widget.apiClient,
  );
  List<Map<String, dynamic>> sources = const [];
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
        sources = result;
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

  void notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
    await run('import', () async {
      final result = await repository.importRepository(
        widget.token,
        url,
        trackingMode: mode,
      );
      await chooseAndApply(result);
    });
  }

  /// Descarga la fuente, deja elegir qué se queda y lo aplica. Cancelar no
  /// cambia nada de lo que ya hubiera.
  Future<void> chooseAndApply(Map<String, dynamic> fetched) async {
    final source = (fetched['source'] as Map?)?.cast<String, dynamic>();
    final components = fetched['components'] as List? ?? const [];
    if (source == null || components.isEmpty || !mounted) return;
    final selected = await showOfficialComponentsDialog(
      context,
      components: components,
      alreadySelected: (fetched['selected'] as List? ?? const [])
          .map((item) => item.toString())
          .toSet(),
      errors: (fetched['errors'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
      tx: widget.tx,
    );
    if (selected == null || !mounted) return;
    final applied = await repository.sync(
      widget.token,
      source['id'].toString(),
      componentIds: selected,
    );
    final result = (applied['applied'] as Map?)?.cast<String, dynamic>();
    if (result == null) return;
    final kept = (result['resources'] as List? ?? const []).length;
    final removed = result['removed'] ?? 0;
    notify(
      widget
          .tx(
            'official.sync_applied',
            '{kept} objetos disponibles, {removed} eliminados',
          )
          .replaceAll('{kept}', '$kept')
          .replaceAll('{removed}', '$removed'),
    );
  }

  Future<void> syncSource(Map<String, dynamic> source) async {
    final id = source['id'].toString();
    await run(id, () async {
      final fetched = await repository.sync(widget.token, id);
      await chooseAndApply(fetched);
    });
  }

  Future<void> editSource(Map<String, dynamic> source) async {
    final payload = await showOfficialSourceEditDialog(
      context,
      source: source,
      tx: widget.tx,
    );
    if (payload == null || !mounted) return;
    final id = source['id'].toString();
    await run(id, () => repository.updateSource(widget.token, id, payload));
  }

  Future<void> deleteSource(Map<String, dynamic> source) async {
    final id = source['id'].toString();
    final name = source['name']?.toString().trim().isNotEmpty == true
        ? source['name'].toString()
        : widget.tx('official.unnamed_package', 'Fuente sin nombre');
    final confirmed = await showConfirmActionDialog(
      context,
      title: widget.tx('official.delete_title', 'Eliminar fuente oficial'),
      message: widget
          .tx(
            'official.delete_confirm',
            'Se eliminarán {name} y todos los objetos que trajo. Los enlaces '
                'y copias que hayan hecho los usuarios seguirán su curso normal.',
          )
          .replaceAll('{name}', name),
      cancelLabel: widget.tx('common.cancel', 'Cancelar'),
      confirmLabel: widget.tx('common.delete', 'Eliminar'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await run(id, () async {
      final result = await repository.deleteSource(widget.token, id);
      notify(
        widget
            .tx('official.deleted', '{count} objetos eliminados')
            .replaceAll('{count}', '${result['removed_resources'] ?? 0}'),
      );
    });
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
            child: PrimaryButton.icon(
              onPressed: busy.contains('import') ? null : openImport,
              icon: const Icon(Icons.add_link),
              label: Text(
                widget.tx('official.admin_add_source', 'Añadir fuente oficial'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final source in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _sourceCard(source),
            ),
          if (sources.isEmpty)
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

  /// Misma anatomía que las demás cards del panel: título, contexto y
  /// acciones al pie.
  Widget _sourceCard(Map<String, dynamic> source) {
    final id = source['id'].toString();
    final name = source['name']?.toString().trim() ?? '';
    final syncError = source['last_sync_error']?.toString() ?? '';
    final resources = (source['resources'] as List? ?? const []).length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isNotEmpty
                  ? name
                  : widget.tx('official.unnamed_package', 'Fuente sin nombre'),
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              source['repository_url']?.toString() ?? '',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              widget
                  .tx('official.source_resources', '{count} objetos en el hub')
                  .replaceAll('{count}', '$resources'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (syncError.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                syncError,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  tooltip: widget.tx(
                    'official.sync_source',
                    'Sincronizar y elegir contenido',
                  ),
                  onPressed: busy.contains(id) ? null : () => syncSource(source),
                  icon: Icons.sync,
                ),
                ActionIconButton(
                  tooltip: widget.tx('common.edit', 'Editar'),
                  onPressed: busy.contains(id) ? null : () => editSource(source),
                  icon: Icons.edit_outlined,
                ),
                ActionIconButton(
                  tooltip: widget.tx(
                    'official.delete_source',
                    'Eliminar fuente',
                  ),
                  onPressed: busy.contains(id)
                      ? null
                      : () => deleteSource(source),
                  icon: Icons.delete_outline,
                  danger: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
