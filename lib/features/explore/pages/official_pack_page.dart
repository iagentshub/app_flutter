import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../../../models/explore/explore_models.dart';
import '../../../shared/graph/graph_dialog.dart';
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
  final String Function(String path, String fallback) tx;

  @override
  State<OfficialPackPage> createState() => _OfficialPackPageState();
}

class _OfficialPackPageState extends State<OfficialPackPage> {
  final _searchController = TextEditingController();
  ExploreOfficialPackDetail? _detail;
  String? _error;
  String _type = 'all';
  bool _loading = true;
  bool _linking = false;
  final Set<String> _selected = {};

  String _tx(String path, String fallback) => widget.tx(path, fallback);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _error = _tx('explore.pack_load_error', 'No se pudo cargar el pack');
        _loading = false;
      });
    }
  }

  List<ExploreOfficialPackComponent> get _visibleComponents {
    final query = _searchController.text.trim().toLowerCase();
    return (_detail?.components ?? const []).where((component) {
      if (_type != 'all' && component.resourceType != _type) return false;
      return query.isEmpty ||
          component.name.toLowerCase().contains(query) ||
          component.description.toLowerCase().contains(query);
    }).toList();
  }

  void _toggle(ExploreOfficialPackComponent component, bool selected) {
    final components = {
      for (final item in _detail?.components ?? const [])
        item.componentKey: item,
    };
    setState(() {
      if (selected) {
        void include(String key) {
          final item = components[key];
          if (item == null ||
              !item.selectable ||
              item.linked ||
              !_selected.add(key)) {
            return;
          }
          for (final dependency in item.dependencies) {
            include(dependency);
          }
        }

        include(component.componentKey);
      } else {
        final removed = <String>{component.componentKey};
        var changed = true;
        while (changed) {
          changed = false;
          for (final item in components.values) {
            if (_selected.contains(item.componentKey) &&
                item.dependencies.any(removed.contains) &&
                removed.add(item.componentKey)) {
              changed = true;
            }
          }
        }
        _selected.removeAll(removed);
      }
    });
  }

  Future<void> _showGraph() async {
    try {
      final graph = await widget.repository.getOfficialPackGraph(
        widget.token,
        widget.pack.sourceId,
      );
      if (!mounted) return;
      await showResourceGraphDialog(
        context: context,
        title: _tx('explore.pack_graph', 'Grafo del pack'),
        nodes: graph.nodes,
        edges: graph.edges,
        rootId: graph.rootId,
        closeLabel: _tx('common.close', 'Cerrar'),
        searchHint: _tx('graph.search_hint', 'Buscar en el grafo...'),
        sortTooltip: _tx('graph.sort_tooltip', 'Ordenar'),
        sortHierarchyVerticalLabel: _tx(
          'graph.sort_hierarchy_vertical',
          'Jerárquico (arriba-abajo)',
        ),
        sortHierarchyHorizontalLabel: _tx(
          'graph.sort_hierarchy_horizontal',
          'Jerárquico (izquierda-derecha)',
        ),
        sortGalaxyLabel: _tx('graph.sort_galaxy', 'Galaxia'),
        showLabelsTooltip: _tx('graph.show_labels_tooltip', 'Mostrar nombres'),
        hideLabelsTooltip: _tx('graph.hide_labels_tooltip', 'Ocultar nombres'),
        quickViewDescriptionLabel: _tx(
          'graph.quick_view_description',
          'Descripción',
        ),
        quickViewNoDescriptionLabel: _tx(
          'graph.quick_view_no_description',
          'Sin descripción',
        ),
        quickViewConnectionsLabel: _tx(
          'graph.quick_view_connections',
          'Conexiones',
        ),
        quickViewNoConnectionsLabel: _tx(
          'graph.quick_view_no_connections',
          'Sin conexiones',
        ),
        emptyLabel: _tx('explore.pack_empty', 'El pack no tiene recursos'),
      );
    } on ApiError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
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
            _tx(
              'explore.pack_link_ok',
              '{{count}} recursos vinculados',
            ).replaceAll('{{count}}', '${result.createdCount}'),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on ApiError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      setState(() => _linking = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _tx('explore.pack_link_error', 'No se pudo vincular el pack'),
          ),
        ),
      );
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
            tooltip: _tx('explore.pack_graph', 'Grafo del pack'),
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
                    _tx(
                      'explore.pack_selected',
                      '{{count}} seleccionados',
                    ).replaceAll('{{count}}', '${_selected.length}'),
                  );
                  final action = PrimaryButton.icon(
                    onPressed: _selected.isEmpty || _linking
                        ? null
                        : _linkSelection,
                    icon: _linking
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.link),
                    label: Text(
                      _tx('explore.pack_link_selection', 'Vincular selección'),
                    ),
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    final detail = _detail!;
    final visible = _visibleComponents;
    final types = detail.components.map((item) => item.resourceType).toSet()
      ..remove('unknown');
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: ListView(
            padding: EdgeInsets.all(constraints.maxWidth < 600 ? 12 : 20),
            children: [
              _buildHeader(detail.pack),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: _tx(
                    'explore.pack_search',
                    'Buscar dentro del pack',
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: Text(_tx('explore.type_all', 'Todos')),
                    selected: _type == 'all',
                    onSelected: (_) => setState(() => _type = 'all'),
                  ),
                  for (final type in types)
                    ChoiceChip(
                      label: Text(_typeLabel(type)),
                      selected: _type == type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                  SecondaryButton(
                    onPressed: () => setState(() {
                      _selected
                        ..clear()
                        ..addAll(
                          detail.components
                              .where((item) => item.selectable && !item.linked)
                              .map((item) => item.componentKey),
                        );
                    }),
                    child: Text(
                      _tx('explore.pack_select_all', 'Seleccionar todo'),
                    ),
                  ),
                  SecondaryButton(
                    onPressed: () => setState(_selected.clear),
                    child: Text(_tx('explore.pack_clear', 'Limpiar selección')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final component in visible) _buildComponent(component),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _tx('explore.pack_empty_filter', 'No hay coincidencias'),
                    textAlign: TextAlign.center,
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
                      _tx('explore.pack_already_linked', 'Ya vinculado'),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'agent' => _tx('explore.type_agents', 'Agentes'),
    'skill' => _tx('explore.type_skills', 'Skills'),
    'prompt' => _tx('explore.type_prompts', 'Prompts'),
    'tool' => _tx('explore.type_tools', 'Herramientas'),
    'knowledge' => _tx('explore.type_knowledge', 'Knowledge'),
    'workflow' => _tx('explore.type_workflows', 'Workflows'),
    'memory' => _tx('explore.type_memory', 'Memoria'),
    _ => type,
  };
}
