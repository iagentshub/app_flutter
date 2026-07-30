import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';
import '../../../core/network/api_client.dart';
import '../../../models/dashboard/dashboard_data.dart';
import '../../../models/dashboard/dashboard_widget_config.dart';
import '../../../models/dashboard/dashboard_widget_instance.dart';
import '../../../models/dashboard/dashboard_widget_registry.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../explore/repositories/explore_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../../../shared/i18n/translated_texts.dart';
import '../../../shared/state/backend_controller.dart';
import '../../../shared/state/dashboard_edit_state.dart';
import '../../../shared/state/locale_controller.dart';
import '../../../shared/state/session_controller.dart';
import '../../../shared/widgets/responsive_dialog.dart';
import '../widgets/responsive_dashboard_grid.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    required this.backendController,
    required this.sessionController,
    required this.authRepository,
    required this.dashboardRepository,
    required this.apiClient,
    required this.dashboardEditState,
    required this.localeController,
    super.key,
  });

  final BackendController backendController;
  final SessionController sessionController;
  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final ApiClient apiClient;
  final DashboardEditState dashboardEditState;
  final LocaleController localeController;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late final ExploreRepository _exploreRepository;
  late final TranslatedTexts _t;

  DashboardData? _data;
  List<DashboardWidgetInstance> _layout = defaultDashboardInstances();
  bool _loading = true;
  bool _editing = false;
  String? _error;

  String _tx(String path, String fallback) => _t.text(path, fallback: fallback);

  String _widgetTx(String key, String fallback) =>
      _tx('dashboard.$key', fallback);

  @override
  void initState() {
    super.initState();
    _exploreRepository = ExploreRepository(apiClient: widget.apiClient);
    _t = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'resources',
    )..addListener(_onTextsChanged);
    _load();
  }

  void _onTextsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_editing) widget.dashboardEditState.stopEditing();
    _t.removeListener(_onTextsChanged);
    _t.dispose();
    super.dispose();
  }

  String? get _token => widget.sessionController.gaToken;

  Future<void> _load() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      setState(() {
        _error = _tx('common.no_session', 'No hay sesión activa');
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preferences = await widget.dashboardRepository.getPreferences(
        token,
      );
      final data = await widget.dashboardRepository.fetchData(
        gaToken: token,
        sources: dashboardDataSourcesFor(preferences.instances),
      );
      if (!mounted) return;
      setState(() {
        _data = data;
        _layout = preferences.instances;
        _loading = false;
      });
      if (!preferences.isVersioned) _persistLayout();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _tx(
          'dashboard.error_generic',
          'No se pudo cargar el dashboard',
        );
        _loading = false;
      });
    }
  }

  Future<void> _persistLayout() async {
    final token = _token;
    if (token == null) return;
    try {
      await widget.dashboardRepository.savePreferences(token, _layout);
    } catch (_) {
      // best-effort: el layout sigue aplicado localmente aunque falle el guardado
    }
  }

  List<String> get _availableWidgetTypes {
    return [
      for (final definition in dashboardWidgetDefinitions)
        if (!definition.singleton ||
            !_layout.any((item) => item.type == definition.type))
          definition.type,
    ];
  }

  void _toggleEditing() {
    setState(() => _editing = !_editing);
    if (_editing) {
      widget.dashboardEditState.startEditing(
        missing: _availableWidgetTypes,
        onAdd: _addWidget,
      );
    } else {
      widget.dashboardEditState.stopEditing();
    }
  }

  void _addWidget(String type) {
    setState(() => _layout = [..._layout, createDashboardWidgetInstance(type)]);
    widget.dashboardEditState.updateMissing(_availableWidgetTypes);
    _persistLayout();
    _reloadDataForCurrentLayout();
  }

  void _removeWidget(String instanceId) {
    setState(() => _layout = _layout.where((w) => w.id != instanceId).toList());
    widget.dashboardEditState.updateMissing(_availableWidgetTypes);
    _persistLayout();
  }

  Future<void> _reloadDataForCurrentLayout() async {
    final token = _token;
    if (token == null) return;
    final data = await widget.dashboardRepository.fetchData(
      gaToken: token,
      sources: dashboardDataSourcesFor(_layout),
    );
    if (mounted) setState(() => _data = data);
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

  Future<void> _editWidget(DashboardWidgetInstance instance) async {
    final result = await showDialog<_DashboardWidgetEditResult>(
      context: context,
      builder: (context) => _WidgetConfigDialog(
        widgetType: instance.type,
        initialConfig: instance.config,
        initialSize: instance.size,
        tx: _widgetTx,
      ),
    );
    if (result == null) return;
    setState(() {
      _layout = [
        for (final item in _layout)
          if (item.id == instance.id)
            item.copyWith(size: result.size, config: result.config)
          else
            item,
      ];
    });
    _persistLayout();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || _data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error ?? _tx('dashboard.no_data', 'Sin datos')),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: Text(_tx('common.retry', 'Reintentar')),
            ),
          ],
        ),
      );
    }

    final data = _data!;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_editing)
                Expanded(
                  child: Text(
                    _tx(
                      'dashboard.edit_hint',
                      'Abre el menú (☰) para añadir widgets',
                    ),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                )
              else
                const Spacer(),
              TextButton.icon(
                onPressed: _toggleEditing,
                icon: Icon(_editing ? Icons.check : Icons.tune),
                label: Text(
                  _editing
                      ? _tx('dashboard.done_btn', 'Listo')
                      : _tx('dashboard.customize_btn', 'Personalizar'),
                ),
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
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            _tx(
                              'dashboard.empty_layout',
                              'No hay widgets. Pulsa "Personalizar" y abre el menú para añadir alguno.',
                            ),
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
                : CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverToBoxAdapter(
                          child: ResponsiveDashboardGrid(
                            items: _layout,
                            itemBuilder: (context, instance, index) =>
                                _buildCard(instance, data, inGrid: true),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(
    DashboardWidgetInstance instance,
    DashboardData data, {
    int index = 0,
    bool inGrid = false,
  }) {
    final definition = dashboardWidgetDefinition(instance.type);
    return Card(
      key: ValueKey(instance.id),
      margin: inGrid ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
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
                    dashboardWidgetTitle(instance.type, _widgetTx),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_editing &&
                    (definition?.configurable == true ||
                        (definition?.supportedSizes.length ?? 0) > 1))
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    tooltip: _tx('dashboard.configure_tooltip', 'Configurar'),
                    onPressed: () => _editWidget(instance),
                  ),
                if (_editing)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: _tx('dashboard.remove_tooltip', 'Quitar'),
                    onPressed: () => _removeWidget(instance.id),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _bodyFor(instance.type, data, instance.config),
          ],
        ),
      ),
    );
  }

  Widget _bodyFor(String id, DashboardData data, DashboardWidgetConfig config) {
    switch (id) {
      case 'summary':
        return _SummaryBody(data: data, config: config, tx: _widgetTx);
      case 'token-usage':
        return _TokenUsageBody(data: data, config: config, tx: _widgetTx);
      case 'conn-status':
        return _ConnectionStatusBody(
          key: ValueKey('conn-status-${_token ?? ''}'),
          data: data,
          token: _token ?? '',
          repository: widget.dashboardRepository,
          config: config,
          tx: _widgetTx,
        );
      case 'recent':
        return _RecentAgentsBody(data: data, config: config, tx: _widgetTx);
      case 'recent-conversations':
        return _RecentConversationsBody(
          data: data,
          config: config,
          tx: _widgetTx,
        );
      case 'activity':
        return _ActivityBody(data: data, config: config, tx: _widgetTx);
      case 'composition':
        return _CompositionBody(data: data, tx: _widgetTx);
      case 'feed':
        return _FeedBody(
          key: ValueKey('feed-${config.types}-${config.limit}'),
          token: _token ?? '',
          repository: widget.dashboardRepository,
          exploreRepository: _exploreRepository,
          config: config,
          tx: _widgetTx,
        );
      case 'quick-actions':
        return _QuickActionsBody(config: config, tx: _widgetTx);
      case 'token-kpi':
        return _TokenKpiBody(data: data, config: config, tx: _widgetTx);
      case 'recent-resources':
        return _RecentResourcesBody(data: data, config: config, tx: _widgetTx);
      case 'agent-health':
        return _AgentHealthBody(data: data, config: config, tx: _widgetTx);
      case 'workspace':
        return _WorkspaceBody(data: data, tx: _widgetTx);
      default:
        return const SizedBox.shrink();
    }
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

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
                        summaryItemLabel(item, tx),
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
  const _ActivityBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

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

    if (daily.isEmpty) {
      return Text(tx('no_activity', 'Sin actividad todavía'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tx(
            'total_tokens_days',
            'Total: {{total}} tokens ({{days}} días)',
          ).replaceAll('{{total}}', '$total').replaceAll('{{days}}', '$days'),
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
  const _TokenUsageBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final groupBy = config.groupBy ?? 'connection';
    final scope = config.scope ?? 'all';
    final limit = config.limit ?? 5;

    final personalConnectionIds = data.connections
        .where((c) => c['_personal_key'] == true || c['scope'] == 'personal')
        .map((c) => c['id']?.toString() ?? '')
        .toSet();

    final defaultAgentName = tx('default_agent_name', 'Agente');
    final defaultConnectionName = tx('default_connection_name', 'Conexión');

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
                final name = a['name']?.toString() ?? defaultAgentName;
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
                    defaultConnectionName;
                return MapEntry(name, tokensIn + tokensOut);
              })
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));
    }
    rows = rows.take(limit).toList();
    final max = rows.isEmpty ? 1 : rows.first.value;

    if (rows.isEmpty) {
      return Text(tx('no_token_usage', 'Todavía no hay consumo de tokens'));
    }
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
    required this.tx,
  });

  final DashboardData data;
  final String token;
  final DashboardRepository repository;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

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
      final ids = _connections
          .map((connection) => connection['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      final results = await widget.repository.testAllConnections(
        widget.token,
        ids: ids,
      );
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
    final defaultConnectionName = widget.tx(
      'default_connection_name',
      'Conexión',
    );

    if (connections.isEmpty) {
      return Text(
        widget.tx('no_connections', 'No hay conexiones configuradas'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _tested
                  ? widget
                        .tx(
                          'operational_count',
                          '{{ok}} / {{total}} operativas',
                        )
                        .replaceAll('{{ok}}', '$okCount')
                        .replaceAll('{{total}}', '${connections.length}')
                  : widget.tx('checking', 'Comprobando…'),
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
              defaultConnectionName;
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
  const _RecentAgentsBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final pageSize = config.pageSize ?? 4;
    final recent = data.agents.reversed.take(pageSize).toList();
    final defaultAgentName = tx('default_agent_name', 'Agente');
    if (recent.isEmpty) {
      return Text(tx('no_recent_agents', 'Todavía no hay agentes'));
    }
    return Column(
      children: recent.map((agent) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.smart_toy_outlined),
          title: Text(agent['name']?.toString() ?? defaultAgentName),
          subtitle: agent['model'] != null
              ? Text(agent['model'].toString())
              : null,
          onTap: () => context.go(RouteNames.agents),
        );
      }).toList(),
    );
  }
}

class _RecentConversationsBody extends StatelessWidget {
  const _RecentConversationsBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final limit = config.limit ?? 5;
    final agentNames = {
      for (final agent in data.agents)
        if (agent['id'] != null)
          agent['id'].toString():
              agent['name']?.toString() ?? tx('default_agent_name', 'Agente'),
    };
    final conversations = data.conversations.take(limit).toList();

    if (conversations.isEmpty) {
      return Text(
        tx('no_recent_conversations', 'Todavía no hay conversaciones'),
      );
    }
    return Column(
      children: [
        for (final conversation in conversations)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: const Icon(Icons.forum_outlined),
            title: Text(
              (conversation['title']?.toString().trim().isNotEmpty ?? false)
                  ? conversation['title'].toString()
                  : tx('untitled_conversation', 'Conversación sin título'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              agentNames[conversation['agent_id']?.toString()] ??
                  tx('default_agent_name', 'Agente'),
            ),
            onTap: () => context.go(RouteNames.agents),
          ),
      ],
    );
  }
}

class _CompositionBody extends StatelessWidget {
  const _CompositionBody({required this.data, required this.tx});

  final DashboardData data;
  final DashboardTx tx;

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
    if (top.isEmpty) {
      return Text(tx('no_composition_data', 'Sin datos suficientes todavía'));
    }
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
    required this.tx,
  });

  final String token;
  final DashboardRepository repository;
  final ExploreRepository exploreRepository;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

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
      return Text(
        widget.tx(
          'no_recent_activity',
          'No hay actividad reciente de la comunidad',
        ),
      );
    }

    final defaultResourceName = widget.tx('default_resource_name', 'Recurso');

    return Column(
      children: _items.map((item) {
        final type = item['resource_type']?.toString() ?? '';
        final id = item['resource_id']?.toString() ?? '';
        final key = '$type:$id';
        final starred = _starredOverride[key] ?? item['starred'] == true;
        final name = item['name']?.toString() ?? defaultResourceName;
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

class _QuickActionsBody extends StatelessWidget {
  const _QuickActionsBody({required this.config, required this.tx});

  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final definitions = <String, ({IconData icon, String label, String route})>{
      'agent': (
        icon: Icons.smart_toy_outlined,
        label: tx('action_agent', 'Nuevo agente'),
        route: RouteNames.agents,
      ),
      'connection': (
        icon: Icons.cable_outlined,
        label: tx('action_connection', 'Nueva conexión'),
        route: RouteNames.connections,
      ),
      'workflow': (
        icon: Icons.account_tree_outlined,
        label: tx('action_workflow', 'Nuevo workflow'),
        route: RouteNames.orchestrations,
      ),
      'knowledge': (
        icon: Icons.note_add_outlined,
        label: tx('action_knowledge', 'Añadir conocimiento'),
        route: RouteNames.knowledge,
      ),
    };
    final items = config.items ?? kQuickActionItems;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          if (definitions[item] case final action?)
            ActionChip(
              avatar: Icon(action.icon, size: 18),
              label: Text(action.label),
              onPressed: () => context.go(action.route),
            ),
      ],
    );
  }
}

class _TokenKpiBody extends StatelessWidget {
  const _TokenKpiBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final period = config.period ?? '7d';
    final days = switch (period) {
      'today' => 1,
      '30d' => 30,
      _ => 7,
    };
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: days - 1));
    final previousStart = start.subtract(Duration(days: days));
    var current = 0;
    var previous = 0;
    final series = <double>[];

    for (final point in data.tokenDaily) {
      final date = DateTime.tryParse(point.day);
      if (date == null) continue;
      if (!date.isBefore(start)) {
        current += point.tokens;
        series.add(point.tokens.toDouble());
      } else if (!date.isBefore(previousStart)) {
        previous += point.tokens;
      }
    }

    final delta = previous == 0
        ? null
        : ((current - previous) / previous * 100);
    final positive = (delta ?? 0) >= 0;
    final periodLabel = switch (period) {
      'today' => tx('period_today', 'Hoy'),
      '30d' => tx('period_30d', 'Últimos 30 días'),
      _ => tx('period_7d', 'Últimos 7 días'),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                _formatCompactInt(current),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (delta != null)
              Chip(
                avatar: Icon(
                  positive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                ),
                label: Text('${delta.abs().toStringAsFixed(1)}%'),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
          ],
        ),
        Text(periodLabel, style: Theme.of(context).textTheme.bodySmall),
        if (series.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                values: series,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final path = Path();

    for (var index = 0; index < values.length; index++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * index / (values.length - 1);
      final normalized = range == 0 ? .5 : (values[index] - minValue) / range;
      final y = size.height - normalized * (size.height - 4) - 2;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _RecentResourcesBody extends StatelessWidget {
  const _RecentResourcesBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final selected = (config.types ?? kRecentResourceTypes).toSet();
    final limit = config.limit ?? 6;
    final resources = <({String type, Map<String, dynamic> raw})>[
      if (selected.contains('agent'))
        for (final raw in data.agents) (type: 'agent', raw: raw),
      if (selected.contains('skill'))
        for (final raw in data.skills) (type: 'skill', raw: raw),
      if (selected.contains('knowledge'))
        for (final raw in data.knowledge) (type: 'knowledge', raw: raw),
      if (selected.contains('workflow'))
        for (final raw in data.workflows) (type: 'workflow', raw: raw),
    ]..sort((a, b) => _resourceDate(b.raw).compareTo(_resourceDate(a.raw)));

    if (resources.isEmpty) {
      return Text(tx('no_recent_resources', 'No hay recursos recientes'));
    }

    final metadata = <String, ({IconData icon, String label, String route})>{
      'agent': (
        icon: Icons.smart_toy_outlined,
        label: tx('feed_agent', 'Agente'),
        route: RouteNames.agents,
      ),
      'skill': (
        icon: Icons.auto_awesome_outlined,
        label: tx('feed_skill', 'Skill'),
        route: RouteNames.knowledge,
      ),
      'knowledge': (
        icon: Icons.menu_book_outlined,
        label: tx('feed_knowledge', 'Knowledge'),
        route: RouteNames.knowledge,
      ),
      'workflow': (
        icon: Icons.account_tree_outlined,
        label: tx('summary_workflows', 'Workflow'),
        route: RouteNames.orchestrations,
      ),
    };

    return Column(
      children: [
        for (final resource in resources.take(limit))
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(metadata[resource.type]?.icon),
            title: Text(
              resource.raw['name']?.toString() ??
                  resource.raw['title']?.toString() ??
                  tx('default_resource_name', 'Recurso'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(metadata[resource.type]?.label ?? resource.type),
            onTap: () => context.go(
              metadata[resource.type]?.route ?? RouteNames.dashboard,
            ),
          ),
      ],
    );
  }

  DateTime _resourceDate(Map<String, dynamic> raw) {
    return DateTime.tryParse(
          raw['updated_at']?.toString() ?? raw['created_at']?.toString() ?? '',
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}

class _AgentHealthBody extends StatelessWidget {
  const _AgentHealthBody({
    required this.data,
    required this.config,
    required this.tx,
  });

  final DashboardData data;
  final DashboardWidgetConfig config;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    final connectionIds = data.connections
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final issues = <({Map<String, dynamic> agent, List<String> reasons})>[];

    for (final agent in data.agents) {
      final reasons = <String>[];
      final connectionId = agent['connection_id']?.toString() ?? '';
      if (connectionId.isEmpty || !connectionIds.contains(connectionId)) {
        reasons.add(tx('health_no_connection', 'sin conexión'));
      }
      final prompt =
          agent['system_prompt']?.toString() ??
          agent['instructions']?.toString() ??
          '';
      if (prompt.trim().isEmpty) {
        reasons.add(tx('health_no_instructions', 'sin instrucciones'));
      }
      if (reasons.isNotEmpty) issues.add((agent: agent, reasons: reasons));
    }

    final total = data.agents.length;
    final ready = total - issues.length;
    final ratio = total == 0 ? 0.0 : ready / total;
    final limit = config.limit ?? 4;

    if (total == 0) {
      return Text(tx('no_recent_agents', 'Todavía no hay agentes'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tx('health_ready_count', '{{ready}} de {{total}} listos')
                    .replaceAll('{{ready}}', '$ready')
                    .replaceAll('{{total}}', '$total'),
              ),
            ),
            Text('${(ratio * 100).round()}%'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: ratio),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (final issue in issues.take(limit))
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              title: Text(
                issue.agent['name']?.toString() ??
                    tx('default_agent_name', 'Agente'),
              ),
              subtitle: Text(issue.reasons.join(' · ')),
              onTap: () => context.go(RouteNames.agents),
            ),
        ],
      ],
    );
  }
}

class _WorkspaceBody extends StatelessWidget {
  const _WorkspaceBody({required this.data, required this.tx});

  final DashboardData data;
  final DashboardTx tx;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic>? active;
    for (final workspace in data.workspaces) {
      if (workspace['active'] == true) {
        active = workspace;
        break;
      }
    }
    final teamCount = data.workspaces
        .where((workspace) => workspace['type'] == 'team')
        .length;

    if (active == null) {
      return Text(tx('workspace_empty', 'No hay workspace activo'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const CircleAvatar(child: Icon(Icons.groups_outlined)),
          title: Text(active['name']?.toString() ?? 'Workspace'),
          subtitle: Text(
            active['role']?.toString() ?? tx('workspace_member', 'Miembro'),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _WorkspaceStat(
                value: '$teamCount',
                label: tx('workspace_teams', 'Equipos'),
              ),
            ),
            Expanded(
              child: _WorkspaceStat(
                value: '${data.invitations.length}',
                label: tx('workspace_invitations', 'Invitaciones'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.go(RouteNames.manager),
            icon: const Icon(Icons.settings_outlined),
            label: Text(tx('workspace_manage', 'Gestionar')),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceStat extends StatelessWidget {
  const _WorkspaceStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _formatCompactInt(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  }
  return '$value';
}

class _DashboardWidgetEditResult {
  const _DashboardWidgetEditResult({required this.config, required this.size});

  final DashboardWidgetConfig config;
  final DashboardWidgetSize size;
}

class _WidgetConfigDialog extends StatefulWidget {
  const _WidgetConfigDialog({
    required this.widgetType,
    required this.initialConfig,
    required this.initialSize,
    required this.tx,
  });

  final String widgetType;
  final DashboardWidgetConfig initialConfig;
  final DashboardWidgetSize initialSize;
  final DashboardTx tx;

  @override
  State<_WidgetConfigDialog> createState() => _WidgetConfigDialogState();
}

class _WidgetConfigDialogState extends State<_WidgetConfigDialog> {
  late DashboardWidgetConfig _draft;
  late DashboardWidgetSize _size;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialConfig;
    _size = widget.initialSize;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget
            .tx('configure_widget_title', 'Configurar: {{name}}')
            .replaceAll(
              '{{name}}',
              dashboardWidgetTitle(widget.widgetType, widget.tx),
            ),
      ),
      content: SizedBox(
        width: dialogContentWidth(context, 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sizeSelector(),
              const SizedBox(height: 16),
              _buildFields(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.tx('common.cancel', 'Cancelar')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(_DashboardWidgetEditResult(config: _draft, size: _size)),
          child: Text(widget.tx('common.save', 'Guardar')),
        ),
      ],
    );
  }

  Widget _buildFields() {
    final tx = widget.tx;
    switch (widget.widgetType) {
      case 'summary':
        return _checklist(
          kSummaryItems,
          _draft.items ?? kSummaryItems,
          (item) => summaryItemLabel(item, tx),
          (next) => setState(() => _draft = _draft.copyWith(items: next)),
        );
      case 'token-usage':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pillRow(
              tx('group_by_label', 'Agrupar por'),
              {
                'connection': tx('group_by_connection', 'Conexión'),
                'agent': tx('group_by_agent', 'Agente'),
              },
              _draft.groupBy ?? 'connection',
              (v) => setState(() => _draft = _draft.copyWith(groupBy: v)),
            ),
            const SizedBox(height: 12),
            _pillRow(
              tx('connections_label', 'Conexiones'),
              {
                'all': tx('scope_all', 'Todas'),
                'personal': tx('scope_personal', 'Personales'),
              },
              _draft.scope ?? 'all',
              (v) => setState(() => _draft = _draft.copyWith(scope: v)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              tx('quantity_label', 'Cantidad'),
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
              tx('connections_label', 'Conexiones'),
              {
                'all': tx('scope_all', 'Todas'),
                'personal': tx('scope_personal', 'Personales'),
              },
              _draft.scope ?? 'all',
              (v) => setState(() => _draft = _draft.copyWith(scope: v)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              tx('quantity_label', 'Cantidad'),
              [2, 4, 6, 8],
              _draft.pageSize ?? 4,
              (v) => setState(() => _draft = _draft.copyWith(pageSize: v)),
            ),
          ],
        );
      case 'recent':
        return _numberRow(
          tx('quantity_label', 'Cantidad'),
          [2, 4, 6, 8],
          _draft.pageSize ?? 4,
          (v) => setState(() => _draft = _draft.copyWith(pageSize: v)),
        );
      case 'recent-conversations':
        return _numberRow(
          tx('quantity_label', 'Cantidad'),
          [3, 5, 8],
          _draft.limit ?? 5,
          (value) => setState(() => _draft = _draft.copyWith(limit: value)),
        );
      case 'activity':
        return _numberRow(
          tx('period_days_label', 'Periodo (días)'),
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
              (type) => feedTypeLabel(type, tx),
              (next) => setState(() => _draft = _draft.copyWith(types: next)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              tx('quantity_label', 'Cantidad'),
              [4, 8, 15, 25],
              _draft.limit ?? 8,
              (v) => setState(() => _draft = _draft.copyWith(limit: v)),
            ),
          ],
        );
      case 'quick-actions':
        return _checklist(
          kQuickActionItems,
          _draft.items ?? kQuickActionItems,
          (item) => switch (item) {
            'agent' => tx('action_agent', 'Nuevo agente'),
            'connection' => tx('action_connection', 'Nueva conexión'),
            'workflow' => tx('action_workflow', 'Nuevo workflow'),
            _ => tx('action_knowledge', 'Añadir conocimiento'),
          },
          (next) => setState(() => _draft = _draft.copyWith(items: next)),
        );
      case 'token-kpi':
        return _pillRow(
          tx('period_label', 'Periodo'),
          {
            'today': tx('period_today', 'Hoy'),
            '7d': tx('period_7d', '7 días'),
            '30d': tx('period_30d', '30 días'),
          },
          _draft.period ?? '7d',
          (value) => setState(() => _draft = _draft.copyWith(period: value)),
        );
      case 'recent-resources':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _checklist(
              kRecentResourceTypes,
              _draft.types ?? kRecentResourceTypes,
              (type) => switch (type) {
                'agent' => tx('feed_agent', 'Agentes'),
                'skill' => tx('feed_skill', 'Skills'),
                'workflow' => tx('summary_workflows', 'Workflows'),
                _ => tx('feed_knowledge', 'Knowledge'),
              },
              (next) => setState(() => _draft = _draft.copyWith(types: next)),
            ),
            const SizedBox(height: 12),
            _numberRow(
              tx('quantity_label', 'Cantidad'),
              [4, 6, 10],
              _draft.limit ?? 6,
              (value) => setState(() => _draft = _draft.copyWith(limit: value)),
            ),
          ],
        );
      case 'agent-health':
        return _numberRow(
          tx('quantity_label', 'Cantidad'),
          [2, 4, 6],
          _draft.limit ?? 4,
          (value) => setState(() => _draft = _draft.copyWith(limit: value)),
        );
      default:
        return Text(
          tx(
            'no_widget_options',
            'Este widget no tiene opciones configurables.',
          ),
        );
    }
  }

  Widget _sizeSelector() {
    final definition = dashboardWidgetDefinition(widget.widgetType);
    final sizes = definition?.supportedSizes ?? {DashboardWidgetSize.medium};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.tx('size_label', 'Tamaño'),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final size in sizes)
              ChoiceChip(
                label: Text(switch (size) {
                  DashboardWidgetSize.compact => widget.tx(
                    'size_compact',
                    'Compacto',
                  ),
                  DashboardWidgetSize.medium => widget.tx(
                    'size_medium',
                    'Mediano',
                  ),
                  DashboardWidgetSize.wide => widget.tx('size_wide', 'Ancho'),
                  DashboardWidgetSize.full => widget.tx(
                    'size_full',
                    'Completo',
                  ),
                }),
                selected: _size == size,
                onSelected: (_) => setState(() => _size = size),
              ),
          ],
        ),
      ],
    );
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
