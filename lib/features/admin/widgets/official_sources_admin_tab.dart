import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/action_icon_button.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/confirm_action_dialog.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../../../utils/i18n.dart';
import '../dialogs/official_source_dialogs.dart';
import '../models/official_import_models.dart';
import '../pages/official_import_review_page.dart';
import '../repositories/admin_connections_repository.dart';
import '../repositories/admin_official_sources_repository.dart';
import 'official_import_progress_dialog.dart';

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
  final String Function(String) tx;

  @override
  State<OfficialSourcesAdminTab> createState() =>
      _OfficialSourcesAdminTabState();
}

class _OfficialSourcesAdminTabState extends State<OfficialSourcesAdminTab> {
  late final repository = AdminOfficialSourcesRepository(
    apiClient: widget.apiClient,
  );
  late final connectionsRepository = AdminConnectionsRepository(
    apiClient: widget.apiClient,
  );
  List<OfficialSource> sources = const [];
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openImport() async {
    final controller = TextEditingController();
    String trackingMode = 'release';
    String importMode = 'deterministic';
    String? llmConnectionId;
    List<OfficialImportLlmConnection> llmConnections = const [];
    try {
      llmConnections = await connectionsRepository.listLlmConnections(
        widget.token,
      );
    } catch (_) {
      // El modo determinista sigue disponible si el catálogo de conexiones
      // no se puede cargar.
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    final accepted = await showAppDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          title: Text(widget.tx('official.admin_import')),
          content: SizedBox(
            width: dialogContentWidth(context, 560),
            child: SingleChildScrollView(
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
                    initialValue: importMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: widget.tx('official.analysis_mode'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'deterministic',
                        child: Text(tr('admin.deterministic_rules')),
                      ),
                      DropdownMenuItem(
                        value: 'llm',
                        child: Text(tr('admin.llm_semantic_analysis')),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() {
                      importMode = value ?? importMode;
                      if (importMode != 'llm') llmConnectionId = null;
                    }),
                  ),
                  if (importMode == 'llm') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: llmConnectionId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: widget.tx('official.llm_connection'),
                        helperText: llmConnections.isEmpty
                            ? widget.tx('official.llm_no_connections')
                            : widget.tx('official.llm_usage_hint'),
                      ),
                      items: [
                        for (final connection in llmConnections)
                          DropdownMenuItem(
                            value: connection.id,
                            child: Text(connection.displayName),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => llmConnectionId = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: trackingMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: widget.tx('official.tracking'),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'release',
                        child: Text(tr('admin.last_release')),
                      ),
                      DropdownMenuItem(
                        value: 'branch',
                        child: Text(tr('admin.main_branch')),
                      ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => trackingMode = value ?? trackingMode,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TertiaryButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.tx('common.cancel')),
            ),
            PrimaryButton(
              onPressed: importMode == 'llm' && llmConnectionId == null
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(widget.tx('common.import')),
            ),
          ],
        ),
      ),
    );
    final url = controller.text.trim();
    controller.dispose();
    if (accepted != true || url.isEmpty) return;
    await run('import', () async {
      final result = await showAppDialog<ImportDraft>(
        context: context,
        barrierDismissible: false,
        builder: (_) => OfficialImportProgressDialog(
          events: repository.importRepositoryStream(
            widget.token,
            url,
            trackingMode: trackingMode,
            importMode: importMode,
            llmConnectionId: llmConnectionId,
          ),
          tx: widget.tx,
        ),
      );
      if (result == null || !mounted) return;
      await chooseAndApply(result);
    });
  }

  /// Descarga la fuente, deja elegir qué se queda y lo aplica. Cancelar no
  /// cambia nada de lo que ya hubiera.
  Future<void> chooseAndApply(ImportDraft draft) async {
    if (draft.components.isEmpty || !mounted) return;
    if (draft.id.isNotEmpty) {
      final applied = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => OfficialImportReviewPage(
            draft: draft,
            repository: repository,
            token: widget.token,
            tx: widget.tx,
          ),
        ),
      );
      if (applied == null || !mounted) return;
      final kept = (applied['resources'] as List? ?? const []).length;
      final removed = applied['removed'] ?? 0;
      notify(
        widget
            .tx('official.sync_applied')
            .replaceAll('{kept}', '$kept')
            .replaceAll('{removed}', '$removed'),
      );
      return;
    }

    // Compatibilidad temporal con backends anteriores al contrato de draft.
    final selected = await showOfficialComponentsDialog(
      context,
      components: draft.components
          .map(
            (item) => {
              'component_id': item.id,
              'component_type': item.type,
              'name': item.name,
              'source_path': item.sourcePath,
              'dependencies': item.dependencies,
              'materializable': item.materializable,
            },
          )
          .toList(growable: false),
      alreadySelected: draft.components
          .where((item) => item.selected)
          .map((item) => item.id)
          .toSet(),
      errors: draft.errors,
      tx: widget.tx,
    );
    if (selected == null || !mounted) return;
    final applied = await repository.sync(
      widget.token,
      draft.source.id,
      componentIds: selected,
    );
    final result = (applied['applied'] as Map?)?.cast<String, dynamic>();
    if (result == null) return;
    final kept = (result['resources'] as List? ?? const []).length;
    final removed = result['removed'] ?? 0;
    notify(
      widget
          .tx('official.sync_applied')
          .replaceAll('{kept}', '$kept')
          .replaceAll('{removed}', '$removed'),
    );
  }

  Future<void> syncSource(OfficialSource source) async {
    final id = source.id;
    await run(id, () async {
      final fetched = await repository.createSyncDraft(widget.token, id);
      await chooseAndApply(fetched);
    });
  }

  Future<void> editSource(OfficialSource source) async {
    final payload = await showOfficialSourceEditDialog(
      context,
      source: source.toJson(),
      tx: widget.tx,
    );
    if (payload == null || !mounted) return;
    final id = source.id;
    await run(id, () => repository.updateSource(widget.token, id, payload));
  }

  Future<void> deleteSource(OfficialSource source) async {
    final id = source.id;
    final name = source.name.trim().isNotEmpty
        ? source.name
        : widget.tx('official.unnamed_package');
    final confirmed = await showConfirmActionDialog(
      context,
      title: widget.tx('official.delete_title'),
      message: widget.tx('official.delete_confirm').replaceAll('{name}', name),
      cancelLabel: widget.tx('common.cancel'),
      confirmLabel: widget.tx('common.delete'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await run(id, () async {
      final result = await repository.deleteSource(widget.token, id);
      notify(
        widget
            .tx('official.deleted')
            .replaceAll('{count}', '${result['removed_resources'] ?? 0}'),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: IAgentsLoadingMark());
    if (error != null) return Center(child: Text(error!));
    return RefreshIndicator(
      onRefresh: load,
      // Cada fuente pinta su lista de recursos sincronizados, así que la
      // pantalla crece con el contenido del hub y no solo con el número de
      // fuentes: las tarjetas se construyen según entran en pantalla.
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.centerLeft,
                child: PrimaryButton.icon(
                  onPressed: busy.contains('import') ? null : openImport,
                  icon: const Icon(Icons.add_link),
                  label: Text(widget.tx('official.admin_add_source')),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: sources.isEmpty
                ? SliverToBoxAdapter(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(widget.tx('official.admin_empty')),
                      ),
                    ),
                  )
                : SliverList.builder(
                    itemCount: sources.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _sourceCard(sources[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Misma anatomía que las demás cards del panel: título, contexto y
  /// acciones al pie.
  Widget _sourceCard(OfficialSource source) {
    final id = source.id;
    final name = source.name.trim();
    final syncError = source.lastSyncError ?? '';
    final resources = source.resources.length;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name.isNotEmpty ? name : widget.tx('official.unnamed_package'),
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              source.repositoryUrl,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              widget
                  .tx('official.source_resources')
                  .replaceAll('{count}', '$resources'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              source.importMode == 'llm'
                  ? widget.tx('official.mode_llm')
                  : widget.tx('official.mode_deterministic'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (syncError.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                syncError,
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                const Spacer(),
                ActionIconButton(
                  tooltip: widget.tx('official.sync_source'),
                  onPressed: busy.contains(id)
                      ? null
                      : () => syncSource(source),
                  icon: Icons.sync,
                ),
                ActionIconButton(
                  tooltip: widget.tx('common.edit'),
                  onPressed: busy.contains(id)
                      ? null
                      : () => editSource(source),
                  icon: Icons.edit_outlined,
                ),
                ActionIconButton(
                  tooltip: widget.tx('official.delete_source'),
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
