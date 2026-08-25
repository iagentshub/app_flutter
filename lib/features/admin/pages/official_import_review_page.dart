import 'package:flutter/material.dart';

import '../../../app/theme/fnc_fonts.dart';
import '../../../shared/graph/graph_dialog.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/motion/app_modal.dart';
import '../models/official_import_models.dart';
import '../repositories/admin_official_sources_repository.dart';
import '../widgets/official_import_groups.dart';
import '../widgets/official_import_review_toolbar.dart';

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
  final String Function(String path) tx;

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
  bool showOmitted = false;
  bool showLogs = false;
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
          if (!showOmitted && component.omitted) return false;
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

  Future<void> setToolLanguage(ImportComponent component, String? value) =>
      mutate(
        () async => widget.repository.updateDraftComponent(
          widget.token,
          draft.id,
          component.id,
          forcedToolLanguage: value ?? '',
        ),
      );

  Future<void> reviewTool(ImportComponent component) async {
    var accepted = component.securityAccepted;
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(widget.tx('official.review_tool')),
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
                        ? widget.tx('official.tool_blocked')
                        : widget.tx('official.tool_accept'),
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
              child: Text(widget.tx('common.cancel')),
            ),
            PrimaryButton(
              onPressed: accepted && !component.securityBlocked
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(widget.tx('common.confirm')),
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
                'tool',
                'memory',
              }.contains(item.effectiveType),
        )
        .toList(growable: false);
    final result = await showAppDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(widget.tx('official.relations')),
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
              child: Text(widget.tx('common.cancel')),
            ),
            PrimaryButton(
              onPressed: () => Navigator.pop(context, selected),
              child: Text(widget.tx('common.save')),
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
      if (component.effectiveType == 'tool' && component.toolLanguage == null) {
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
      final confirmed = await showAppDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(widget.tx('official.confirm_apply')),
          content: Text(
            widget
                .tx('official.diff_summary')
                .replaceAll('{create}', '${diff.counts['create'] ?? 0}')
                .replaceAll('{update}', '${diff.counts['update'] ?? 0}')
                .replaceAll('{delete}', '${diff.counts['delete'] ?? 0}'),
          ),
          actions: [
            TertiaryButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(widget.tx('common.cancel')),
            ),
            PrimaryButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(widget.tx('official.apply')),
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
        title: widget.tx('official.preview_graph'),
        nodes: graph.nodes,
        edges: graph.edges,
        rootId: graph.rootId,
        closeLabel: widget.tx('common.close'),
        searchHint: widget.tx('graph.search_hint'),
        sortTooltip: widget.tx('graph.sort_tooltip'),
        sortHierarchyVerticalLabel: widget.tx('graph.sort_hierarchy_vertical'),
        sortHierarchyHorizontalLabel: widget.tx(
          'graph.sort_hierarchy_horizontal',
        ),
        sortGalaxyLabel: widget.tx('graph.sort_galaxy'),
        showLabelsTooltip: widget.tx('graph.show_labels_tooltip'),
        hideLabelsTooltip: widget.tx('graph.hide_labels_tooltip'),
        quickViewDescriptionLabel: widget.tx('graph.quick_view_description'),
        quickViewNoDescriptionLabel: widget.tx(
          'graph.quick_view_no_description',
        ),
        quickViewConnectionsLabel: widget.tx('graph.quick_view_connections'),
        quickViewNoConnectionsLabel: widget.tx(
          'graph.quick_view_no_connections',
        ),
        emptyLabel: widget.tx('admin.graph_empty'),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 700;
        final padding = constraints.maxWidth >= 1024 ? 28.0 : 12.0;
        final groupsSliver = OfficialImportGroupsSliver(
          groups: groups,
          busy: busy,
          tx: widget.tx,
          onToggle: toggle,
          onClassify: setClassification,
          onLanguage: setLanguage,
          onToolLanguage: setToolLanguage,
          onEditRelations: editRelations,
          onReviewTool: reviewTool,
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.tx('official.review_title')),
            actions: mobile
                ? null
                : [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: PrimaryButton(
                        onPressed: canApply ? apply : null,
                        child: Text(widget.tx('official.apply')),
                      ),
                    ),
                  ],
          ),
          bottomNavigationBar: mobile
              ? SafeArea(
                  minimum: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: PrimaryButton(
                    onPressed: canApply ? apply : null,
                    child: Text(widget.tx('official.apply')),
                  ),
                )
              : null,
          body: SafeArea(
            child: mobile
                ? CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(padding, 12, padding, 8),
                        sliver: SliverToBoxAdapter(
                          child: _toolbar(
                            availableWidth:
                                constraints.maxWidth - (padding * 2),
                            mobile: true,
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(padding, 0, padding, 24),
                        sliver: groupsSliver,
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(padding, 12, padding, 8),
                        child: _toolbar(
                          availableWidth: constraints.maxWidth - (padding * 2),
                          mobile: false,
                        ),
                      ),
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                padding,
                                0,
                                padding,
                                24,
                              ),
                              sliver: groupsSliver,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _toolbar({required double availableWidth, required bool mobile}) =>
      OfficialImportReviewToolbar(
        draft: draft,
        searchController: search,
        selectedType: type,
        selectedState: state,
        showOmitted: showOmitted,
        showLogs: showLogs,
        busy: busy,
        availableWidth: availableWidth,
        mobile: mobile,
        error: error,
        tx: widget.tx,
        onSearchChanged: (_) => setState(() {}),
        onTypeChanged: (value) => setState(() => type = value ?? 'all'),
        onStateChanged: (value) => setState(() => state = value ?? 'all'),
        onShowOmittedChanged: (value) => setState(() => showOmitted = value),
        onShowLogsChanged: (value) => setState(() => showLogs = value),
        onSelectVisible: () => bulkSelect(true),
        onDeselectVisible: () => bulkSelect(false),
        onShowGraph: showGraph,
      );
}
