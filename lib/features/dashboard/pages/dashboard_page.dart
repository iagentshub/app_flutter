import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_client.dart';
import '../../../models/dashboard/dashboard_data.dart';
import '../../../models/dashboard/dashboard_widget_config.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../explore/repositories/explore_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/dashboard_edit_state.dart';
import '../../../shared/state/session_controller.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.backendController,
    required this.sessionController,
    required this.authRepository,
    required this.dashboardRepository,
    required this.apiClient,
    required this.dashboardEditState,
    super.key,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final ApiClient apiClient;
  final DashboardEditState dashboardEditState;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final ExploreRepository _exploreRepository;

  DashboardData? _data;
  List<String> _layout = kDefaultDashboardLayout;
  Map<String, DashboardWidgetConfig> _config = const {};
  bool _loading = true;
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _exploreRepository = ExploreRepository(apiClient: widget.apiClient);
    _load();
  }

  @override
  void dispose() {
    if (_editing) widget.dashboardEditState.stopEditing();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'No hay sesión activa';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.dashboardRepository.fetchData(gaToken: token),
        widget.dashboardRepository.getLayout(token),
        widget.dashboardRepository.getConfig(token),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as DashboardData;
        _layout = (results[1] as List<String>?) ?? kDefaultDashboardLayout;
        _config = results[2] as Map<String, DashboardWidgetConfig>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar el dashboard';
        _loading = false;
      });
    }
  }

  Future<void> _persistLayout() async {
    final token = _token;
    if (token == null) return;
    try {
      await widget.dashboardRepository.saveLayout(token, _layout);
    } catch (_) {
      // best-effort: el layout sigue aplicado localmente aunque falle el guardado
    }
  }

  Future<void> _persistConfig() async {
    final token = _token;
    if (token == null) return;
    try {
      await widget.dashboardRepository.saveConfig(token, _config);
    } catch (_) {
      // best-effort
    }
  }

  List<String> get _missingWidgets =>
      kDashboardWidgetIds.where((id) => !_layout.contains(id)).toList();

  void _toggleEditing() {
    setState(() => _editing = !_editing);
    if (_editing) {
      widget.dashboardEditState.startEditing(
        missing: _missingWidgets,
        onAdd: _addWidget,
        onDone: () {
          if (mounted) setState(() => _editing = false);
          widget.dashboardEditState.stopEditing();
        },
      );
    } else {
      widget.dashboardEditState.stopEditing();
    }
  }

  void _addWidget(String id) {
    setState(() => _layout = [..._layout, id]);
    widget.dashboardEditState.updateMissing(_missingWidgets);
    _persistLayout();
  }

  void _removeWidget(String id) {
    setState(() => _layout = _layout.where((w) => w != id).toList());
    widget.dashboardEditState.updateMissing(_missingWidgets);
    _persistLayout();
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final list = [..._layout];
      if (newIndex > oldIndex) newIndex -= 1;
      final item = list.removeAt(oldIndex);
      list.insert(newIndex, item);
      _layout = list;
    });
    _persistLayout();
  }

  Future<void> _editWidget(String id) async {
    final current = _config[id] ?? const DashboardWidgetConfig();
    final result = await showDialog<DashboardWidgetConfig>(
      context: context,
      builder: (context) => _WidgetConfigDialog(widgetId: id, initial: current),
    );
    if (result == null) return;
    setState(() => _config = {..._config, id: result});
    _persistConfig();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? 'Sin datos'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    final data = _data!;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_editing)
                    const Expanded(
                      child: Text(
                        'Abre el menú (☰) para añadir widgets',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    )
                  else
                    const Spacer(),
                  TextButton.icon(
                    onPressed: _toggleEditing,
                    icon: Icon(_editing ? Icons.check : Icons.tune),
                    label: Text(_editing ? 'Listo' : 'Personalizar'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: _layout.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'No hay widgets. Pulsa "Personalizar" y abre el menú para añadir alguno.',
                              ),
                            ),
                          ),
                        ],
                      )
                    : _editing
                    ? ReorderableListView.builder(
                        padding: const EdgeInsets.all(16),
                        buildDefaultDragHandles: false,
                        itemCount: _layout.length,
                        onReorder: _reorder,
                        itemBuilder: (context, index) =>
                            _buildCard(_layout[index], data, index: index),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _layout.length,
                        itemBuilder: (context, index) =>
                            _buildCard(_layout[index], data),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String id, DashboardData data, {int index = 0}) {
    final config = _config[id] ?? const DashboardWidgetConfig();
    return Card(
      key: ValueKey(id),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (_editing)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Icon(Icons.drag_handle),
                    ),
                  ),
                Expanded(
                  child: Text(
                    dashboardWidgetTitle(id),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_editing && id != 'composition')
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: 'Configurar',
                    onPressed: () => _editWidget(id),
                  ),
                if (_editing)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Quitar',
                    onPressed: () => _removeWidget(id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _bodyFor(id, data, config),
          ],
        ),
      ),
    );
  }

  Widget _bodyFor(String id, DashboardData data, DashboardWidgetConfig config) {
    switch (id) {
      case 'summary':
        return _SummaryBody(data: data, config: config);
      case 'token-usage':
        return _TokenUsageBody(data: data, config: config);
      case 'conn-status':
        return _ConnectionStatusBody(
          key: ValueKey('conn-status-${_token ?? ''}'),
          data: data,
          token: _token ?? '',
          repository: widget.dashboardRepository,
          config: config,
        );
      case 'recent':
        return _RecentAgentsBody(data: data, config: config);
      case 'activity':
        return _ActivityBody(data: data, config: config);
      case 'composition':
        return _CompositionBody(data: data);
      case 'feed':
        return _FeedBody(
          key: ValueKey('feed-${config.types}-${config.limit}'),
          token: _token ?? '',
          repository: widget.dashboardRepository,
          exploreRepository: _exploreRepository,
          config: config,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.data, required this.config});

  final DashboardData data;
  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{
      'agents': data.agents.length,
      'connections': data.connections.length,
      'skills': data.skills.length,
      'memory': data.memory.length,
      'knowledge': data.knowledge.length,
      'workflows': data.workflows.length,
    };
    final routes = <String, String>{
      'agents': RouteNames.agents,
      'connections': RouteNames.connections,
      'skills': RouteNames.knowledge,
      'memory': RouteNames.knowledge,
      'knowledge': RouteNames.knowledge,
      'workflows': RouteNames.orchestrations,
    };
    final icons = <String, IconData>{
      'agents': Icons.smart_toy_outlined,
      'connections': Icons.cable_outlined,
      'skills': Icons.auto_awesome_outlined,
      'memory': Icons.description_outlined,
      'knowledge': Icons.menu_book_outlined,
      'workflows': Icons.account_tree_outlined,
    };
    final items = config.items ?? kSummaryItems;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 90,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: InkWell(
            onTap: () => context.go(routes[item] ?? RouteNames.dashboard),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    icons[item] ?? Icons.circle_outlined,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${counts[item] ?? 0}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        summaryItemLabel(item),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody({required this.data, required this.config});

  final DashboardData data;
  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final days = config.days ?? 14;
    final all = data.tokenDaily;
    final daily = all.length > days ? all.sublist(all.length - days) : all;
    final total = daily.fold<int>(0, (sum, item) => sum + item.tokens);
    final max = daily.fold<int>(
      0,
      (m, item) => item.tokens > m ? item.tokens : m,
    );

    if (daily.isEmpty) return const Text('Sin actividad todavía');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total: $total tokens ($days días)',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: daily.map((point) {
              final ratio = max > 0 ? point.tokens / max : 0.0;
              return Expanded(
                child: Tooltip(
                  message: '${point.day}: ${point.tokens} tokens',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: FractionallySizedBox(
                      heightFactor: ratio.clamp(0.03, 1.0),
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              daily.first.day,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            Text(daily.last.day, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ],
    );
  }
}

class _TokenUsageBody extends StatelessWidget {
  const _TokenUsageBody({required this.data, required this.config});

  final DashboardData data;
  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final groupBy = config.groupBy ?? 'connection';
    final scope = config.scope ?? 'all';
    final limit = config.limit ?? 5;

    final personalConnectionIds = data.connections
        .where((c) => c['_personal_key'] == true || c['scope'] == 'personal')
        .map((c) => c['id']?.toString() ?? '')
        .toSet();

    List<MapEntry<String, int>> rows;
    if (groupBy == 'agent') {
      final agents = data.agents.where((a) {
        if (scope != 'personal') return true;
        final connId = a['connection_id']?.toString();
        return connId == null ||
            connId.isEmpty ||
            personalConnectionIds.contains(connId);
      });
      rows =
          agents
              .map((a) {
                final tokensIn = (a['tokens_in'] as num?)?.toInt() ?? 0;
                final tokensOut = (a['tokens_out'] as num?)?.toInt() ?? 0;
                final name = a['name']?.toString() ?? 'Agente';
                return MapEntry(name, tokensIn + tokensOut);
              })
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
    } else {
      final connections = scope == 'personal'
          ? data.connections.where(
              (c) => personalConnectionIds.contains(c['id']),
            )
          : data.connections;
      rows =
          connections
              .map((c) {
                final tokensIn = (c['tokens_in'] as num?)?.toInt() ?? 0;
                final tokensOut = (c['tokens_out'] as num?)?.toInt() ?? 0;
                final name =
                    c['name']?.toString() ??
                    c['type']?.toString() ??
                    'Conexión';
                return MapEntry(name, tokensIn + tokensOut);
              })
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
    }
    rows = rows.take(limit).toList();
    final max = rows.isEmpty ? 1 : rows.first.value;

    if (rows.isEmpty) return const Text('Todavía no hay consumo de tokens');
    return Column(
      children: rows.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(entry.key, overflow: TextOverflow.ellipsis),
                  ),
                  Text('${entry.value}'),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: entry.value / max,
                  minHeight: 6,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _ConnectionStatusBody extends StatefulWidget {
  const _ConnectionStatusBody({
    super.key,
    required this.data,
    required this.token,
    required this.repository,
    required this.config,
  });

  final DashboardData data;
  final String token;
  final DashboardRepository repository;
  final DashboardWidgetConfig config;

  @override
  State<_ConnectionStatusBody> createState() => _ConnectionStatusBodyState();
}

class _ConnectionStatusBodyState extends State<_ConnectionStatusBody> {
  bool _testing = false;
  List<ConnectionTestResult> _results = const [];
  bool _tested = false;

  List<Map<String, dynamic>> get _connections {
    final scope = widget.config.scope ?? 'all';
    if (scope != 'personal') return widget.data.connections;
    return widget.data.connections
        .where((c) => c['_personal_key'] == true || c['scope'] == 'personal')
        .toList();
  }

  @override
  void initState() {
    super.initState();
    if (_connections.isNotEmpty) _runTest();
  }

  Future<void> _runTest() async {
    setState(() => _testing = true);
    try {
      final results = await widget.repository.testAllConnections(widget.token);
      if (!mounted) return;
      setState(() {
        _results = results;
        _tested = true;
      });
    } catch (_) {
      // silencioso: el panel simplemente no mostrará resultados
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final connections = _connections;
    final pageSize = widget.config.pageSize ?? 4;
    final resultsById = {for (final r in _results) r.id: r};
    final okCount = _results.where((r) => r.ok).length;

    if (connections.isEmpty) {
      return const Text('No hay conexiones configuradas');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _tested
                  ? '$okCount / ${connections.length} operativas'
                  : 'Comprobando…',
            ),
            IconButton(
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 20),
              onPressed: _testing ? null : _runTest,
            ),
          ],
        ),
        ...connections.take(pageSize).map((conn) {
          final id = conn['id']?.toString() ?? '';
          final name =
              conn['name']?.toString() ??
              conn['type']?.toString() ??
              'Conexión';
          final result = resultsById[id];
          final color = result == null
              ? Colors.grey
              : (result.ok ? Colors.green.shade600 : Colors.red.shade600);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                if (result?.latencyMs != null) Text('${result!.latencyMs}ms'),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _RecentAgentsBody extends StatelessWidget {
  const _RecentAgentsBody({required this.data, required this.config});

  final DashboardData data;
  final DashboardWidgetConfig config;

  @override
  Widget build(BuildContext context) {
    final pageSize = config.pageSize ?? 4;
    final recent = data.agents.reversed.take(pageSize).toList();
    if (recent.isEmpty) return const Text('Todavía no hay agentes');
    return Column(
      children: recent.map((agent) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.smart_toy_outlined),
          title: Text(agent['name']?.toString() ?? 'Agente'),
          subtitle: agent['model'] != null
              ? Text(agent['model'].toString())
              : null,
          onTap: () => context.go(RouteNames.agents),
        );
      }).toList(),
    );
  }
}

class _CompositionBody extends StatelessWidget {
  const _CompositionBody({required this.data});

  final DashboardData data;

  static const _colors = [
    Color(0xFF4F46E5),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final c in data.connections) {
      final key = (c['type']?.toString() ?? 'other').toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    for (final a in data.agents) {
      final model = a['model']?.toString() ?? 'other';
      final key = model.toLowerCase().split(RegExp('[-/]')).first;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final rows = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.take(6).toList();
    if (top.isEmpty) return const Text('Sin datos suficientes todavía');
    final max = top.first.value;

    return Column(
      children: [
        for (var i = 0; i < top.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(top[i].key), Text('${top[i].value}')],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: top[i].value / max,
                    minHeight: 6,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      _colors[i % _colors.length],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FeedBody extends StatefulWidget {
  const _FeedBody({
    super.key,
    required this.token,
    required this.repository,
    required this.exploreRepository,
    required this.config,
  });

  final String token;
  final DashboardRepository repository;
  final ExploreRepository exploreRepository;
  final DashboardWidgetConfig config;

  @override
  State<_FeedBody> createState() => _FeedBodyState();
}

class _FeedBodyState extends State<_FeedBody> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = const [];
  final Map<String, bool> _starredOverride = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await widget.repository.fetchFeed(
      widget.token,
      types: widget.config.types ?? kFeedTypes,
      limit: widget.config.limit ?? 8,
    );
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _toggleStar(Map<String, dynamic> item) async {
    final type = item['resource_type']?.toString() ?? '';
    final id = item['resource_id']?.toString() ?? '';
    final key = '$type:$id';
    final starred = _starredOverride[key] ?? item['starred'] == true;
    try {
      if (starred) {
        await widget.exploreRepository.unstar(
          widget.token,
          resourceType: type,
          resourceId: id,
        );
      } else {
        await widget.exploreRepository.star(
          widget.token,
          resourceType: type,
          resourceId: id,
        );
      }
      if (!mounted) return;
      setState(() => _starredOverride[key] = !starred);
    } catch (_) {
      // ignorar fallo de star silenciosamente
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_items.isEmpty) {
      return const Text('No hay actividad reciente de la comunidad');
    }

    return Column(
      children: _items.map((item) {
        final type = item['resource_type']?.toString() ?? '';
        final id = item['resource_id']?.toString() ?? '';
        final key = '$type:$id';
        final starred = _starredOverride[key] ?? item['starred'] == true;
        final name = item['name']?.toString() ?? 'Recurso';
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
          ),
          title: Text(name),
          subtitle: Text(
            '$type${item['owner'] != null ? ' · @${item['owner']}' : ''}',
          ),
          trailing: IconButton(
            icon: Icon(
              starred ? Icons.star : Icons.star_border,
              color: starred ? Colors.amber : null,
              size: 20,
            ),
            onPressed: () => _toggleStar(item),
          ),
        );
      }).toList(),
    );
  }
}

class _WidgetConfigDialog extends StatefulWidget {
  const _WidgetConfigDialog({required this.widgetId, required this.initial});

  final String widgetId;
  final DashboardWidgetConfig initial;

  @override
  State<_WidgetConfigDialog> createState() => _WidgetConfigDialogState();
}

class _WidgetConfigDialogState extends State<_WidgetConfigDialog> {
  late DashboardWidgetConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Configurar: ${dashboardWidgetTitle(widget.widgetId)}'),
      content: SizedBox(width: 420, child: _buildFields()),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_draft),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _buildFields() {
    switch (widget.widgetId) {
      case 'summary':
        return _checklist(
          kSummaryItems,
          _draft.items ?? kSummaryItems,
          summaryItemLabel,
          (next) => setState(() => _draft = _draft.copyWith(items: next)),
        );
      case 'token-usage':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pillRow(
              'Agrupar por',
              {'connection': 'Conexión', 'agent': 'Agente'},
              _draft.groupBy ?? 'connection',
              (v) => setState(() => _draft = _draft.copyWith(groupBy: v)),
            ),
            const SizedBox(height: 12),
            _pillRow(
              'Conexiones',
              {'all': 'Todas', 'personal': 'Personales'},
              _draft.scope ?? 'all',
              (v) => setState(() => _draft = _draft.copyWith(scope: v)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              'Cantidad',
              [3, 5, 10],
              _draft.limit ?? 5,
              (v) => setState(() => _draft = _draft.copyWith(limit: v)),
            ),
          ],
        );
      case 'conn-status':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pillRow(
              'Conexiones',
              {'all': 'Todas', 'personal': 'Personales'},
              _draft.scope ?? 'all',
              (v) => setState(() => _draft = _draft.copyWith(scope: v)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              'Cantidad',
              [2, 4, 6, 8],
              _draft.pageSize ?? 4,
              (v) => setState(() => _draft = _draft.copyWith(pageSize: v)),
            ),
          ],
        );
      case 'recent':
        return _numberRow(
          'Cantidad',
          [2, 4, 6, 8],
          _draft.pageSize ?? 4,
          (v) => setState(() => _draft = _draft.copyWith(pageSize: v)),
        );
      case 'activity':
        return _numberRow(
          'Periodo (días)',
          [7, 14, 30],
          _draft.days ?? 14,
          (v) => setState(() => _draft = _draft.copyWith(days: v)),
        );
      case 'feed':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _checklist(
              kFeedTypes,
              _draft.types ?? kFeedTypes,
              feedTypeLabel,
              (next) => setState(() => _draft = _draft.copyWith(types: next)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              'Cantidad',
              [4, 8, 15, 25],
              _draft.limit ?? 8,
              (v) => setState(() => _draft = _draft.copyWith(limit: v)),
            ),
          ],
        );
      default:
        return const Text('Este widget no tiene opciones configurables.');
    }
  }

  Widget _checklist(
    List<String> options,
    List<String> selected,
    String Function(String) label,
    void Function(List<String>) onChanged,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: options.map((option) {
        final checked = selected.contains(option);
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          value: checked,
          title: Text(label(option)),
          onChanged: (value) {
            final next = [...selected];
            if (value == true && !next.contains(option)) next.add(option);
            if (value == false) next.remove(option);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }

  Widget _pillRow(
    String label,
    Map<String, String> options,
    String value,
    void Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.entries.map((entry) {
            return ChoiceChip(
              label: Text(entry.value),
              selected: value == entry.key,
              onSelected: (_) => onChanged(entry.key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _numberRow(
    String label,
    List<int> options,
    int value,
    void Function(int) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            return ChoiceChip(
              label: Text('$option'),
              selected: value == option,
              onSelected: (_) => onChanged(option),
            );
          }).toList(),
        ),
      ],
    );
  }
}
