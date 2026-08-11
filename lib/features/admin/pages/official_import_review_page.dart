import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/graph/graph_dialog.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../models/official_import_models.dart';
import '../repositories/admin_official_sources_repository.dart';
import '../widgets/official_import_component_tile.dart';

typedef OfficialImportTx = String Function(String path, String fallback);

class OfficialImportReviewPage extends StatefulWidget {
  const OfficialImportReviewPage({
    required this.draft,
    required this.repository,
    required this.token,
    required this.tx,
    super.key,
  });

  final ImportDraft draft;
  final AdminOfficialSourcesRepository repository;
  final String token;
  final OfficialImportTx tx;

  @override
  State<OfficialImportReviewPage> createState() =>
      _OfficialImportReviewPageState();
}

class _OfficialImportReviewPageState extends State<OfficialImportReviewPage> {
  late ImportDraft draft = widget.draft;
  final search = TextEditingController();
  String type = 'all';
  String state = 'all';
  bool busy = false;
  String? error;

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  List<ImportComponent> get visible {
    final needle = search.text.trim().toLowerCase();
    return draft.components
        .where((component) {
          if (type != 'all' && component.effectiveType != type) return false;
          if (state != 'all' && component.state != state) return false;
          if (needle.isEmpty) return true;
          return component.name.toLowerCase().contains(needle) ||
              component.sourcePath.toLowerCase().contains(needle);
        })
        .toList(growable: false);
  }

  Future<void> refresh() async {
    final updated = await widget.repository.getDraft(widget.token, draft.id);
    if (mounted) setState(() => draft = updated);
  }

  Future<void> mutate(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      await refresh();
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggle(ImportComponent component, bool selected) => mutate(
    () async => widget.repository.updateDraftComponent(
      widget.token,
      draft.id,
      component.id,
      selected: selected,
    ),
  );

  Future<void> bulkSelect(bool selected) => mutate(() async {
    for (final component in visible.where(
      (item) =>
          !item.securityBlocked &&
          (item.materializable || item.forcedType != null || !selected),
    )) {
      await widget.repository.updateDraftComponent(
        widget.token,
        draft.id,
        component.id,
        selected: selected,
      );
    }
  });

  Future<void> setClassification(ImportComponent component, String? value) =>
      mutate(
        () async => widget.repository.updateDraftComponent(
          widget.token,
          draft.id,
          component.id,
          forcedType: value,
        ),
      );

  Future<void> setLanguage(ImportComponent component, String? value) => mutate(
    () async => widget.repository.updateDraftComponent(
      widget.token,
      draft.id,
      component.id,
      forcedLanguage: value ?? '',
    ),
  );

  Future<void> reviewTool(ImportComponent component) async {
    var accepted = component.securityAccepted;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            widget.tx('official.review_tool', 'Revisar herramienta ejecutable'),
          ),
          content: SizedBox(
            width: 760,
            height: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(component.sourcePath),
                const SizedBox(height: 8),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        component.content,
                        style: const TextStyle(fontFamily: FncFonts.monospace),
                      ),
                    ),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: accepted,
                  enabled: !component.securityBlocked,
                  title: Text(
                    component.securityBlocked
                        ? widget.tx(
                            'official.tool_blocked',
                            'La revisión de seguridad bloquea esta herramienta.',
                          )
                        : widget.tx(
                            'official.tool_accept',
                            'He revisado el código y acepto importarlo.',
                          ),
                  ),
                  onChanged: (value) =>
                      setDialogState(() => accepted = value == true),
                ),
              ],
            ),
          ),
          actions: [
            TertiaryButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.tx('common.cancel', 'Cancelar')),
            ),
            PrimaryButton(
              onPressed: accepted && !component.securityBlocked
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(widget.tx('common.confirm', 'Confirmar')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await mutate(
      () async => widget.repository.updateDraftComponent(
        widget.token,
        draft.id,
        component.id,
        securityAccepted: true,
      ),
    );
  }

  Future<void> editRelations(ImportComponent component) async {
    final selected = component.dependencies.toSet();
    final candidates = draft.components
        .where(
          (item) =>
              item.id != component.id &&
              const {
                'skill',
                'knowledge',
                'prompt',
                'command',
                'tool',
                'memory',
              }.contains(item.effectiveType),
        )
        .toList(growable: false);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(widget.tx('official.relations', 'Relaciones del agente')),
          content: SizedBox(
            width: 560,
            height: 460,
            child: ListView(
              children: [
                for (final candidate in candidates)
                  CheckboxListTile(
                    value: selected.contains(candidate.id),
                    title: Text(candidate.name),
                    subtitle: Text(candidate.sourcePath),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selected.add(candidate.id);
                      } else {
                        selected.remove(candidate.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TertiaryButton(
              onPressed: () => Navigator.pop(context),
              child: Text(widget.tx('common.cancel', 'Cancelar')),
            ),
            PrimaryButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text(widget.tx('common.save', 'Guardar')),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    await mutate(
      () async => widget.repository.updateDraftComponent(
        widget.token,
        draft.id,
        component.id,
        dependencies: result.toList(growable: false),
      ),
    );
  }

  bool get canApply {
    if (busy || draft.expired || draft.errors.isNotEmpty) return false;
    for (final component in draft.components.where((item) => item.selected)) {
      if ((!component.materializable && component.forcedType == null) ||
          component.securityBlocked ||
          (component.effectiveType == 'tool' && !component.securityAccepted)) {
        return false;
      }
    }
    return true;
  }

  Future<void> apply() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final diff = await widget.repository.getDiff(widget.token, draft.id);
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            widget.tx('official.confirm_apply', 'Confirmar importación'),
          ),
          content: Text(
            widget
                .tx(
                  'official.diff_summary',
                  'Se crearán {create}, actualizarán {update} y eliminarán '
                      '{delete} recursos.',
                )
                .replaceAll('{create}', '${diff.counts['create'] ?? 0}')
                .replaceAll('{update}', '${diff.counts['update'] ?? 0}')
                .replaceAll('{delete}', '${diff.counts['delete'] ?? 0}'),
          ),
          actions: [
            TertiaryButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.tx('common.cancel', 'Cancelar')),
            ),
            PrimaryButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.tx('official.apply', 'Aplicar cambios')),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      final result = await widget.repository.applyDraft(widget.token, draft.id);
      if (mounted) Navigator.pop(context, result);
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> showGraph() async {
    setState(() => busy = true);
    try {
      final graph = await widget.repository.getDraftGraph(
        widget.token,
        draft.id,
      );
      if (!mounted) return;
      await showResourceGraphDialog(
        context: context,
        title: widget.tx('official.preview_graph', 'Grafo previo'),
        nodes: graph.nodes,
        edges: graph.edges,
        rootId: graph.rootId,
        closeLabel: widget.tx('common.close', 'Cerrar'),
        searchHint: widget.tx('graph.search_hint', 'Buscar en el grafo...'),
        sortTooltip: widget.tx('graph.sort_tooltip', 'Ordenar'),
        sortHierarchyVerticalLabel: widget.tx(
          'graph.sort_hierarchy_vertical',
          'Jerarquía vertical',
        ),
        sortHierarchyHorizontalLabel: widget.tx(
          'graph.sort_hierarchy_horizontal',
          'Jerarquía horizontal',
        ),
        sortGalaxyLabel: widget.tx('graph.sort_galaxy', 'Galaxia'),
        showLabelsTooltip: widget.tx(
          'graph.show_labels_tooltip',
          'Mostrar nombres',
        ),
        hideLabelsTooltip: widget.tx(
          'graph.hide_labels_tooltip',
          'Ocultar nombres',
        ),
        quickViewDescriptionLabel: widget.tx(
          'graph.quick_view_description',
          'Descripción',
        ),
        quickViewNoDescriptionLabel: widget.tx(
          'graph.quick_view_no_description',
          'Sin descripción',
        ),
        quickViewConnectionsLabel: widget.tx(
          'graph.quick_view_connections',
          'Relaciones',
        ),
        quickViewNoConnectionsLabel: widget.tx(
          'graph.quick_view_no_connections',
          'Sin relaciones',
        ),
        emptyLabel: widget.tx(
          'admin.graph_empty',
          'Este objeto no tiene relaciones',
        ),
      );
    } catch (exception) {
      if (mounted) setState(() => error = exception.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ImportComponent>>{};
    for (final component in visible) {
      final directory = component.sourcePath.contains('/')
          ? component.sourcePath.split('/').first
          : '/';
      groups.putIfAbsent(directory, () => []).add(component);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.tx('official.review_title', 'Revisar repositorio oficial'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: PrimaryButton(
              onPressed: canApply ? apply : null,
              child: Text(widget.tx('official.apply', 'Aplicar cambios')),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final padding = constraints.maxWidth >= 1024 ? 28.0 : 12.0;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 12, padding, 8),
                  child: _header(),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
                    children: [
                      for (final entry in groups.entries)
                        Card(
                          child: ExpansionTile(
                            initiallyExpanded: true,
                            title: Text('${entry.key} (${entry.value.length})'),
                            children: [
                              for (final component in entry.value)
                                OfficialImportComponentTile(
                                  component: component,
                                  busy: busy,
                                  tx: widget.tx,
                                  onToggle: (value) => toggle(component, value),
                                  onClassify: (value) =>
                                      setClassification(component, value),
                                  onLanguage: (value) =>
                                      setLanguage(component, value),
                                  onEditRelations: () =>
                                      editRelations(component),
                                  onReviewTool: () => reviewTool(component),
                                ),
                            ],
                          ),
                        ),
                      if (groups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              widget.tx('common.no_results', 'Sin resultados'),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _header() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        draft.source.repositoryUrl,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      if (draft.errors.isNotEmpty)
        _messageBox(draft.errors, Theme.of(context).colorScheme.error),
      if (draft.warnings.isNotEmpty)
        _messageBox(draft.warnings, Theme.of(context).colorScheme.tertiary),
      if (error != null)
        _messageBox([error!], Theme.of(context).colorScheme.error),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: widget.tx('common.search', 'Buscar'),
              ),
            ),
          ),
          _filter(
            value: type,
            label: widget.tx('common.type', 'Tipo'),
            values: const [
              'all',
              'agent',
              'skill',
              'prompt',
              'command',
              'knowledge',
              'memory',
              'tool',
              'workflow',
              'unknown',
            ],
            onChanged: (value) => setState(() => type = value ?? 'all'),
          ),
          _filter(
            value: state,
            label: widget.tx('common.status', 'Estado'),
            values: const [
              'all',
              'new',
              'updated',
              'removed',
              'unchanged',
              'duplicate',
              'unrecognized',
            ],
            onChanged: (value) => setState(() => state = value ?? 'all'),
          ),
          TertiaryButton.icon(
            onPressed: busy ? null : () => bulkSelect(true),
            icon: const Icon(Icons.select_all),
            label: Text(
              widget.tx('official.select_visible', 'Seleccionar visibles'),
            ),
          ),
          TertiaryButton.icon(
            onPressed: busy ? null : () => bulkSelect(false),
            icon: const Icon(Icons.deselect),
            label: Text(
              widget.tx('official.deselect_visible', 'Desmarcar visibles'),
            ),
          ),
          TertiaryButton.icon(
            onPressed: busy ? null : showGraph,
            icon: const Icon(Icons.account_tree_outlined),
            label: Text(widget.tx('official.preview_graph', 'Grafo previo')),
          ),
        ],
      ),
    ],
  );

  Widget _messageBox(List<String> messages, Color color) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: color),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(messages.join('\n')),
  );

  Widget _filter({
    required String value,
    required String label,
    required List<String> values,
    required ValueChanged<String?> onChanged,
  }) => SizedBox(
    width: 180,
    child: DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final item in values)
          DropdownMenuItem(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
    ),
  );
}
