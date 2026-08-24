import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../../shared/graph/graph_dialog.dart';
import '../../../shared/graph/resource_graph_builder.dart';
import '../../../shared/utils/debouncer.dart';
import '../../../shared/widgets/animated_iagents_mark.dart';
import '../../../shared/widgets/buttons/app_buttons.dart';
import '../../../shared/widgets/resource_type_badge.dart';
import '../repositories/explore_repository.dart';

class OfficialPackPage extends StatefulWidget {
  const OfficialPackPage({
    required this.pack,
    required this.repository,
    required this.token,
    required this.tx,
    super.key,
  });

  final ExploreOfficialPack pack;
  final ExploreRepository repository;
  final String token;
  final String Function(String path) tx;

  @override
  State<OfficialPackPage> createState() => _OfficialPackPageState();
}

class _OfficialPackPageState extends State<OfficialPackPage> {
  final _searchController = TextEditingController();
  final _searchDebouncer = Debouncer(delay: const Duration(milliseconds: 150));
  ExploreOfficialPackDetail? _detail;
  Map<String, ExploreOfficialPackComponent> _componentsByKey = const {};
  Map<String, Set<String>> _dependentsByKey = const {};
  List<ExploreOfficialPackComponent> _visibleComponents = const [];
  String? _error;
  String _type = 'all';
  bool _loading = true;
  bool _linking = false;
  final Set<String> _selected = {};

  String _tx(String path) => widget.tx(path);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _indexDetail(ExploreOfficialPackDetail detail) {
    _componentsByKey = {
      for (final component in detail.components)
        component.componentKey: component,
    };
    final dependents = <String, Set<String>>{};
    for (final component in detail.components) {
      for (final dependency in component.dependencies) {
        dependents
            .putIfAbsent(dependency, () => <String>{})
            .add(component.componentKey);
      }
    }
    _dependentsByKey = dependents;
    _refreshVisibleComponents();
  }

  void _refreshVisibleComponents() {
    final query = _searchController.text.trim().toLowerCase();
    _visibleComponents = (_detail?.components ?? const [])
        .where((component) {
          if (_type != 'all' && component.resourceType != _type) return false;
          return query.isEmpty ||
              component.name.toLowerCase().contains(query) ||
              component.description.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _load() async {
    try {
      final detail = await widget.repository.getOfficialPack(
        widget.token,
        widget.pack.sourceId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _indexDetail(detail);
        _selected
          ..clear()
          ..addAll(
            detail.components
                .where((component) => component.selectable && !component.linked)
                .map((component) => component.componentKey),
          );
        _loading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx('explore.pack_load_error');
        _loading = false;
      });
    }
  }

  void _toggle(ExploreOfficialPackComponent component, bool selected) {
    setState(() {
      if (selected) {
        final pending = <String>[component.componentKey];
        while (pending.isNotEmpty) {
          final key = pending.removeLast();
          final item = _componentsByKey[key];
          if (item == null ||
              !item.selectable ||
              item.linked ||
              !_selected.add(key)) {
            continue;
          }
          pending.addAll(item.dependencies);
        }
      } else {
        final removed = <String>{component.componentKey};
        final pending = <String>[component.componentKey];
        while (pending.isNotEmpty) {
          final key = pending.removeLast();
          for (final dependent in _dependentsByKey[key] ?? const <String>{}) {
            if (_selected.contains(dependent) && removed.add(dependent)) {
              pending.add(dependent);
            }
          }
        }
        _selected.removeAll(removed);
      }
    });
  }

  Future<void> _showGraph() async {
    final detail = _detail;
    if (detail == null) return;
    final graph = officialPackGraph(
      sourceId: detail.pack.sourceId,
      sourceName: detail.pack.name,
      sourceDescription: detail.pack.repositoryUrl,
      components: detail.components,
    );
    await showResourceGraphDialog(
      context: context,
      title: _tx('explore.pack_graph'),
      nodes: graph.nodes,
      edges: graph.edges,
      rootId: graph.rootId,
      closeLabel: _tx('common.close'),
      searchHint: _tx('graph.search_hint'),
      sortTooltip: _tx('graph.sort_tooltip'),
      sortHierarchyVerticalLabel: _tx('graph.sort_hierarchy_vertical'),
      sortHierarchyHorizontalLabel: _tx('graph.sort_hierarchy_horizontal'),
      sortGalaxyLabel: _tx('graph.sort_galaxy'),
      showLabelsTooltip: _tx('graph.show_labels_tooltip'),
      hideLabelsTooltip: _tx('graph.hide_labels_tooltip'),
      quickViewDescriptionLabel: _tx('graph.quick_view_description'),
      quickViewNoDescriptionLabel: _tx('graph.quick_view_no_description'),
      quickViewConnectionsLabel: _tx('graph.quick_view_connections'),
      quickViewNoConnectionsLabel: _tx('graph.quick_view_no_connections'),
      emptyLabel: _tx('explore.pack_empty'),
    );
  }

  Future<void> _linkSelection() async {
    if (_selected.isEmpty || _linking) return;
    setState(() => _linking = true);
    try {
      final result = await widget.repository.linkOfficialPack(
        widget.token,
        widget.pack.sourceId,
        commitSha: _detail?.pack.commitSha ?? widget.pack.commitSha,
        componentKeys: _selected.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tx('explore.pack_link_ok')
                .replaceAll('{{count}}', '${result.createdCount}'),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _linking = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_tx('explore.pack_link_error'))));
      setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pack.name),
        actions: [
          AppIconButton(
            onPressed: _loading ? null : _showGraph,
            tooltip: _tx('explore.pack_graph'),
            icon: const Icon(Icons.account_tree_outlined),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _detail == null
          ? null
          : SafeArea(
              minimum: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = Text(
                    _tx('explore.pack_selected')
                        .replaceAll('{{count}}', '${_selected.length}'),
                  );
                  final action = PrimaryButton.icon(
                    onPressed: _selected.isEmpty || _linking
                        ? null
                        : _linkSelection,
                    icon: _linking
                        ? const SizedBox.square(
                            dimension: 16,
                            child: IAgentsLoadingMark(),
                          )
                        : const Icon(Icons.link),
                    label: Text(_tx('explore.pack_link_selection')),
                  );
                  if (constraints.maxWidth < 480) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: count),
                        const SizedBox(height: 8),
                        action,
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [count, const SizedBox(width: 12), action],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: IAgentsLoadingMark());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final detail = _detail!;
    final types = detail.components.map((item) => item.resourceType).toSet()
      ..remove('unknown');
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  constraints.maxWidth < 600 ? 12 : 20,
                  constraints.maxWidth < 600 ? 12 : 20,
                  constraints.maxWidth < 600 ? 12 : 20,
                  12,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(detail.pack),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: _tx('explore.pack_search'),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (_) => _searchDebouncer.run(() {
                        if (!mounted) return;
                        setState(_refreshVisibleComponents);
                      }),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChoiceChip(
                          label: Text(_tx('explore.type_all')),
                          selected: _type == 'all',
                          onSelected: (_) => setState(() {
                            _type = 'all';
                            _refreshVisibleComponents();
                          }),
                        ),
                        for (final type in types)
                          ChoiceChip(
                            label: Text(_typeLabel(type)),
                            selected: _type == type,
                            onSelected: (_) => setState(() {
                              _type = type;
                              _refreshVisibleComponents();
                            }),
                          ),
                        SecondaryButton(
                          onPressed: () => setState(() {
                            _selected
                              ..clear()
                              ..addAll(
                                detail.components
                                    .where(
                                      (item) => item.selectable && !item.linked,
                                    )
                                    .map((item) => item.componentKey),
                              );
                          }),
                          child: Text(_tx('explore.pack_select_all')),
                        ),
                        SecondaryButton(
                          onPressed: () => setState(_selected.clear),
                          child: Text(_tx('explore.pack_clear')),
                        ),
                      ],
                    ),
                  ]),
                ),
              ),
              if (_visibleComponents.isEmpty)
                SliverPadding(
                  padding: const EdgeInsets.all(24),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      _tx('explore.pack_empty_filter'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    constraints.maxWidth < 600 ? 12 : 20,
                    0,
                    constraints.maxWidth < 600 ? 12 : 20,
                    20,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) =>
                          _buildComponent(_visibleComponents[index]),
                      childCount: _visibleComponents.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ExploreOfficialPack pack) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(pack.name, style: Theme.of(context).textTheme.titleLarge),
            if (pack.description.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(pack.description),
            ],
            const SizedBox(height: 8),
            Text(
              pack.repositoryUrl,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComponent(ExploreOfficialPackComponent component) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: CheckboxListTile(
        value: component.linked || _selected.contains(component.componentKey),
        onChanged: component.selectable && !component.linked
            ? (value) => _toggle(component, value ?? false)
            : null,
        controlAffinity: ListTileControlAffinity.leading,
        title: Row(
          children: [
            Expanded(
              child: Text(component.name, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            ResourceTypeBadge(
              type: component.resourceType,
              label: _typeLabel(component.resourceType),
            ),
          ],
        ),
        subtitle: component.description.isEmpty && !component.linked
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (component.description.isNotEmpty)
                    Text(
                      component.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (component.linked)
                    Text(
                      _tx('explore.pack_already_linked'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'agent' => _tx('explore.type_agents'),
    'skill' => _tx('explore.type_skills'),
    'prompt' => _tx('explore.type_prompts'),
    'tool' => _tx('explore.type_tools'),
    'knowledge' => _tx('explore.type_knowledge'),
    'workflow' => _tx('explore.type_workflows'),
    'memory' => _tx('explore.type_memory'),
    _ => type,
  };
}
